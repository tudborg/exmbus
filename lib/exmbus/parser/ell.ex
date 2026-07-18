defmodule Exmbus.Parser.Ell do
  @moduledoc """
  Module responsible for handling the extended link layer
  Spec taken from EN 13757-4:2019.

  See also the Exmbus.Parser.CI module.
  """

  alias Exmbus.Parser.Context
  alias Exmbus.Parser.Ell.CommunicationControl
  alias Exmbus.Parser.Ell.Encrypted
  alias Exmbus.Parser.Ell.None
  alias Exmbus.Parser.Ell.SessionNumber
  alias Exmbus.Parser.Ell.Unencrypted
  alias Exmbus.Parser.Ell.UnencryptedWithReceiver

  @doc """
  Parses an extended link layer and adds it to the parse context.

  In contrast to `parse/1`, this function will not fail if the data
  doesn't contain an ELL. Instead, it will assign a `%None{}` struct
  to the ell context field.
  """
  def maybe_parse(%{} = ctx) do
    case parse(ctx) do
      {:halt, %Context{errors: [{_handler_func, {:ci_not_ell, _ci}} | _]}} ->
        {:next, %{ctx | ell: %None{}}}

      {:halt, ctx} ->
        {:halt, ctx}

      {:next, ctx} ->
        {:next, ctx}
    end
  end

  # > This value of the CI-field is used if data encryption at the link layer is not used in the frame.
  # > Table 44 below, shows the complete extension block in this case.
  # Fields: CC, ACC
  def parse(%{bin: <<0x8C, cc::binary-size(1), acc, rest::binary>>} = ctx) do
    with {:ok, control} <- CommunicationControl.decode(cc) do
      ell = %Unencrypted{
        communication_control: control,
        access_no: acc
      }

      {:next, %{ctx | ell: ell, bin: rest}}
    else
      {:error, reason} -> {:halt, Context.add_error(ctx, {:ell_parse_error, reason, ci: 0x8C})}
    end
  end

  # > This value of the CI-field is used if data encryption at the link layer is used in the frame.
  # > Table 45 below, shows the complete extension block in this case.
  # Fields: CC, ACC, SN, PayloadCRC (the payload is part of encrypted)
  def parse(
        %{
          bin:
            <<0x8D, cc::binary-size(1), acc, sn::binary-size(4), payload_crc::size(16),
              rest::binary>>
        } = ctx
      ) do
    with {:ok, control} <- CommunicationControl.decode(cc),
         {:ok, session_number} <- SessionNumber.decode(sn) do
      ell = %Encrypted{
        communication_control: control,
        access_no: acc,
        session_number: session_number
      }

      {:next, %{ctx | ell: ell, bin: <<payload_crc::size(16), rest::binary>>}}
    else
      {:error, reason} -> {:halt, Context.add_error(ctx, {:ell_parse_error, reason, ci: 0x8D})}
    end
  end

  # > This value of the CI-field is used if data encryption at the link layer is not used in the frame.
  # > This extended link layer specifies the receiver address.
  # > Table 46 below shows the complete extension block in this case.
  # Fields: CC, ACC, M2, A2
  def parse(%{bin: <<0x8E, ell::binary-size(10), rest::binary>>} = ctx) do
    with {:ok, ell} <- UnencryptedWithReceiver.decode(ell) do
      {:next, %{ctx | ell: ell, bin: rest}}
    else
      {:error, reason} ->
        {:halt, Context.add_error(ctx, {:ell_parse_error, reason, ci: 0x8E})}
    end
  end

  # > This value of the CI-field is used if data encryption at the link layer is used in the frame.
  # > This extended link layer specifies the receiver address.
  # > Table 47 below shows the complete extension block in this case.
  # Fields: CC, ACC, M2, A2, SN, PayloadCRC
  def parse(
        %{
          bin:
            <<0x8F, _cc::binary-size(1), _acc, _m2::binary-size(2), _a2::binary-size(6),
              _sn::binary-size(4), _payload_crc::binary-size(2), _rest::binary>>
        } = ctx
      ) do
    {:halt, Context.add_error(ctx, {:not_implemented, :ell_iv})}
  end

  # > The variable Extended Link Layer allows to select optional ELL fields separately.
  # > The shadowed rows of Table 48 shall always be present.
  # > The other fields are optional and can be selected in case they are needed.
  # > The table defines the ordering of the fields.
  def parse(%{bin: <<0x86, _rest::binary>>} = ctx) do
    {:halt, Context.add_error(ctx, {:not_implemented, :ell_v})}
  end

  def parse(%{bin: <<ci, _rest::binary>>} = ctx) when ci in [0x8C, 0x8D, 0x8E, 0x8F] do
    {:halt, Context.add_error(ctx, {:ell_parse_error, :truncated, ci: ci})}
  end

  def parse(%{bin: <<ci, _rest::binary>>} = ctx) do
    {:halt, Context.add_error(ctx, {:ci_not_ell, ci})}
  end

  defdelegate maybe_decrypt_bin(ctx), to: Encrypted
  defdelegate decrypt_bin(ctx), to: Encrypted
  defdelegate encrypt_bin(ctx), to: Encrypted

  # Unparsing the ELL structure, sticking it at the start of bin, clearing ELL, and returning context.

  def unparse(%{ell: %None{}} = ctx) do
    {:next, %{ctx | ell: nil}}
  end

  def unparse(%{ell: %Unencrypted{} = ell} = ctx) do
    {:ok, cc} = CommunicationControl.encode(ell.communication_control)
    acc = ell.access_no
    {:next, %{ctx | ell: nil, bin: <<0x8C, cc::binary-size(1), acc, ctx.bin::binary>>}}
  end

  def unparse(%{ell: %Encrypted{} = ell} = ctx) do
    {:ok, cc} = CommunicationControl.encode(ell.communication_control)
    {:ok, sn} = SessionNumber.encode(ell.session_number)
    acc = ell.access_no

    {:next,
     %{
       ctx
       | ell: nil,
         bin: <<0x8D, cc::binary-size(1), acc, sn::binary-size(4), ctx.bin::binary>>
     }}
  end

  def unparse(%{ell: %UnencryptedWithReceiver{} = ell} = ctx) do
    with {:ok, ell_bin} <- UnencryptedWithReceiver.encode(ell) do
      {:next, %{ctx | ell: nil, bin: <<0x8E, ell_bin::binary-size(10), ctx.bin::binary>>}}
    else
      {:error, reason} ->
        raise "Failed to unparse ELL: #{reason}"
    end
  end
end
