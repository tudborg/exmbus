defmodule Exmbus.Parser.Afl do
  @moduledoc """
  Authentication and Fragmentation Layer (AFL) as per EN 13757-7:2018


  >   The Authentication and Fragmentation Sublayer provides three essential services:
  >
  >   — fragmentation of long messages in multiple datagrams;
  >   — a Message Authentication Code (MAC) to prove the authenticity of the TPL and APL;
  >   — a Message counter which supplies a security relevant message identification that may be used for the key derivation function (refer to 9.6.1).
  >
  >   This optional layer shall be applied if at least one of these services is required.

  Overview of the AFL layer:

  | Size (bytes) | Field Name | Description                                                                 |
  |--------------|------------|-----------------------------------------------------------------------------|
  | 1            | CI         | Indicates that an Authentication and Fragmentation Sublayer follows.        |
  | 1            | AFLL       | AFL-Length                                                                  |
  | 2            | FCL        | Fragmentation Control field                                                 |
  | 1            | MCL        | Message Control field *a                                                     |
  | 2            | KI         | Key Information field *a                                                     |
  | 4            | MCR        | Message counter field *a                                                     |
  | N *b         | MAC        | Message Authentication Code *a                                               |
  | 2            | ML         | Message Length field *a                                                      |

  - `*a` This is an optional field. Their inclusion is defined by the Fragmentation Control Field specified in 6.3.2.
  - `*b` The length of MAC depends on AT-subfield in AFL.MCL.

  > All multi byte fields of AFL except the AFL.MAC shall be transmitted with least significant byte first (little endian).
  """

  alias Exmbus.Crypto
  alias Exmbus.Parser.Afl.MessageLengthField
  alias Exmbus.Parser.Afl.MessageCounterField
  alias Exmbus.Parser.Afl.KeyInformationField
  alias Exmbus.Parser.Tpl.Encryption
  alias Exmbus.Parser.Afl.MessageControlField
  alias Exmbus.Parser.Afl.FragmentationControlField
  alias Exmbus.Parser.Context
  alias Exmbus.Parser.Afl.None

  defstruct [
    # Fragmentation Control Field
    fcl: nil,
    # Message Control Field
    mcl: nil,
    # Key Information Field
    ki: nil,
    # Message Counter Field
    mcr: nil,
    # Message Authentication Code (MAC)
    mac: nil,
    # Message Length
    ml: nil,
    # optimization used to verify the MAC
    _tpdu_bytes: nil
  ]

  @doc """
  Returns true if this message is part of a fragmented message.
  """
  def fragmented?(%__MODULE__{fcl: fcl}) do
    FragmentationControlField.fragmented?(fcl)
  end

  @doc """
  Parses an AFL and add it to the parse context.

  In contrast to `parse/1`, this function will not fail if the data
  doesn't contain an AFL. Instead, it will assign a `%None{}` struct
  to the ell context field.
  """
  def maybe_parse(%{bin: <<0x90, _::binary>>} = ctx), do: parse(ctx)
  def maybe_parse(%{bin: <<_ci, _rest::binary>>} = ctx), do: {:next, %{ctx | afl: %None{}}}

  @doc """
  Parses an AFL and add it to the parse context.
  """

  # AFL Fields: AFLL, FCL, MCL, KI, MCR, MAC, ML
  # see table in module doc
  # we can parse up to the MAC
  def parse(%{bin: <<0x90, afll::8, afl_bytes::binary-size(afll), rest::binary>>} = ctx) do
    <<fcl_bytes::binary-size(2), bytes::binary>> = afl_bytes
    {:ok, fcl} = FragmentationControlField.decode(fcl_bytes)

    # our "accumulator" for the AFL layer
    afl = %__MODULE__{fcl: fcl}

    # consume the rest of the AFL. Each field is optional and
    # may or may not be present. It's presence is defined by the
    # Fragmentation Control Field (FCL) and the Message Control Field (MCL) (which itself is optional)
    with {:ok, afl, bytes} <- consume_mcl(bytes, afl),
         {:ok, afl, bytes} <- consume_ki(bytes, afl),
         {:ok, afl, bytes} <- consume_mcr(bytes, afl),
         {:ok, afl, bytes} <- consume_mac(bytes, afl),
         {:ok, afl, bytes} <- consume_ml(bytes, afl) do
      # AFL should be the afl struct
      %__MODULE__{} = afl
      # there should be no remaining AFL bytes
      <<>> = bytes

      # we have a complete AFL layer
      # NOTE: verification of the MAC is not done here, because we potentially need
      # the TPL CF field to decide what key to use.
      # so we "remember" the TPDU bytes for later.
      # I don't like this solution, but anything else requires a change in architecture
      # or re-encoding the TPDU bytes after we've parsed the TPL.
      afl =
        case fcl.mac_present? do
          true -> %{afl | _tpdu_bytes: rest}
          false -> afl
        end

      {:next, %{ctx | afl: afl, bin: rest}}
    else
      {:error, reason} -> {:halt, Context.add_error(ctx, reason)}
    end
  end

  def parse(%{bin: <<ci, _rest::binary>>} = ctx) do
    {:halt, Context.add_error(ctx, {:ci_not_afl, ci})}
  end

  @doc """
  Verifies the MAC of the AFL.
  NOTE: This handler should be attached _after_ the TPL has been parsed,
  so that we can use the TPL CF field to determine the key to use.
  """
  def maybe_verify_mac(%{afl: %{mac: nil}} = ctx) do
    # No MAC, just continue:
    {:next, ctx}
  end

  def maybe_verify_mac(%{afl: %{mac: mac} = afl} = ctx) when is_binary(mac) do
    case MessageControlField.authentication_type(afl.mcl) do
      # No MAC, just continue:
      {:none, _} -> {:next, ctx}
      # delegate to the correct MAC verification:
      {:aes_cmac_128, size} -> verify_aes_cmac_128(size, ctx)
      {:aes_gmac_128, size} -> verify_aes_gmac_128(size, ctx)
    end
  end

  def maybe_verify_mac(%{afl: nil} = ctx) do
    {:next, ctx}
  end

  def maybe_verify_mac(%{afl: %None{}} = ctx) do
    {:next, ctx}
  end

  defp verify_aes_cmac_128(size, ctx) do
    with {:ok, keys} <- Encryption.keys(ctx, :mac) do
      mcl_bytes = MessageControlField.encode(ctx.afl.mcl)
      ki_bytes = KeyInformationField.encode(ctx.afl.ki)
      mcr_bytes = MessageCounterField.encode(ctx.afl.mcr)
      ml_bytes = MessageLengthField.encode(ctx.afl.ml)

      # AFL.MAC = CMAC (Kmac/Lmac, AFL.MCL || {AFL.KI} || {AFL.MCR} || {AFL.ML} || First byte of TPDU (CI-field) || ... || Last byte of TPDU)
      data = <<
        mcl_bytes::binary,
        ki_bytes::binary,
        mcr_bytes::binary,
        ml_bytes::binary,
        ctx.afl._tpdu_bytes::binary
      >>

      calculated_macs =
        keys
        |> Enum.map(&Crypto.cmac!(&1, data))
        |> Enum.map(&:binary.part(&1, 0, size))

      if ctx.afl.mac in calculated_macs do
        # MAC is valid, continue
        {:next, ctx}
      else
        # MAC is invalid, add error to context
        {:halt, Context.add_error(ctx, {:invalid_mac, ctx.afl.mac, calculated_macs})}
      end
    end
  end

  defp verify_aes_gmac_128(_size, ctx) do
    {:halt, Context.add_error(ctx, {:not_implemeneted, :aes_gmac_128})}
  end

  ##
  ## Consumer functions to parse AFL fields
  ##

  defp consume_mcl(
         <<bytes::binary-size(1), rest::binary>>,
         %{fcl: %{message_control_present?: true}} = afl
       ) do
    with {:ok, mcl} <- MessageControlField.decode(bytes) do
      {:ok, %{afl | mcl: mcl}, rest}
    end
  end

  defp consume_mcl(rest, %{fcl: %{message_control_present?: false}} = afl) do
    {:ok, afl, rest}
  end

  defp consume_ki(
         <<bytes::binary-size(2), rest::binary>>,
         %{fcl: %{key_information_present?: true}} = afl
       ) do
    with {:ok, ki} <- Exmbus.Parser.Afl.KeyInformationField.decode(bytes) do
      {:ok, %{afl | ki: ki}, rest}
    end
  end

  defp consume_ki(rest, %{fcl: %{key_information_present?: false}} = afl) do
    {:ok, afl, rest}
  end

  defp consume_mcr(
         <<bytes::binary-size(4), rest::binary>>,
         %{fcl: %{message_counter_present?: true}} = afl
       ) do
    with {:ok, mcr} <- Exmbus.Parser.Afl.MessageCounterField.decode(bytes) do
      {:ok, %{afl | mcr: mcr}, rest}
    end
  end

  defp consume_mcr(rest, %{fcl: %{message_counter_present?: false}} = afl) do
    {:ok, afl, rest}
  end

  defp consume_mac(bytes, %{fcl: %{mac_present?: true}, mcl: %MessageControlField{} = mcl} = afl) do
    {_, mac_size} = MessageControlField.authentication_type(mcl)
    <<mac::binary-size(mac_size), rest::binary>> = bytes
    {:ok, %{afl | mac: mac}, rest}
  end

  defp consume_mac(rest, %{fcl: %{mac_present?: false}} = afl) do
    {:ok, afl, rest}
  end

  defp consume_ml(
         <<bytes::binary-size(2), rest::binary>>,
         %{fcl: %{message_length_present?: true}} = afl
       ) do
    with {:ok, ml} <- Exmbus.Parser.Afl.MessageLengthField.decode(bytes) do
      {:ok, %{afl | ml: ml}, rest}
    end
  end

  defp consume_ml(rest, %{fcl: %{message_length_present?: false}} = afl) do
    {:ok, afl, rest}
  end
end
