defmodule Exmbus.Parser.Ell.Encrypted do
  alias Exmbus.Parser.Context
  alias Exmbus.Parser.Manufacturer
  alias Exmbus.Parser.DataType
  alias Exmbus.Parser.Tpl.Device
  alias Exmbus.Parser.Ell.SessionNumber
  alias Exmbus.Parser.Ell.CommunicationControl

  defstruct communication_control: nil,
            access_no: nil,
            session_number: nil

  @doc """
  decrypts the context data according to the ELL layer.

  This function will decrypt the encrypted bytes according to the ELL encryption mode.
  """

  def decrypt_rest(
        %{
          rest: <<payload_crc::little-size(16), plain::binary>>,
          ell: %__MODULE__{session_number: %{encryption: :none}}
        } = ctx
      ) do
    # encryption mode is none, so we just need to verify the payload crc
    # assuming that this was a CI=8D or CI=8F
    case verify_crc(payload_crc, plain) do
      {:ok, rest} -> {:continue, Context.merge(ctx, rest: rest)}
      {:error, reason} -> {:abort, Context.add_error(ctx, reason)}
    end
  end

  def decrypt_rest(%{ell: %__MODULE__{session_number: %{encryption: :aes_128_ctr}}} = ctx) do
    with {:ok, icb} <- icb(ctx),
         {:ok, keys} <- Exmbus.Key.get(ctx) do
      case try_decrypt_and_verify(ctx.rest, icb, keys, []) do
        {:ok, rest} -> {:continue, Context.merge(ctx, rest: rest)}
        {:error, reason} -> {:abort, Context.add_error(ctx, reason)}
      end
    end
  end

  def decrypt_rest(ctx) do
    # no encryption mode found, continue assuming payload not ELL encrypted
    {:continue, ctx}
  end

  # calculate the initial counter block for the ELL AES-128-CTR decryption
  defp icb(ctx) do
    frame_number = 0
    block_counter = 0

    # 13.2.12.4Communication Control Field (CC-field)
    # The value is retrieved from the Extended Link Layer, see 13.2.7.
    # The bits of the Communication Control Field handled by the repeater
    # (R-field and H-field) are always set to zero in the Initial Counter Block.
    cc_for_icb = %{ctx.ell.communication_control | hop_count: false, repeated_access: false}

    with {:ok, identification_bytes} <- identity_from_ctx(ctx),
         {:ok, cc_bytes} <- CommunicationControl.encode(cc_for_icb),
         {:ok, sn_bytes} <- SessionNumber.encode(ctx.ell.session_number) do
      # initial counter block
      {:ok,
       <<
         # identification_bytes is
         # manufacturer + serial + device + version (as in the Wmbus DLL)
         identification_bytes::binary,
         cc_bytes::binary,
         sn_bytes::binary,
         frame_number::little-size(16),
         block_counter
       >>}
    end
  end

  # no keys, no errors (so no keys was tried)
  defp try_decrypt_and_verify(_bin, _icb, [], []) do
    {:error, {:ell_decryption_failed, :no_keys_available}}
  end

  defp try_decrypt_and_verify(_bin, _icb, [], error_acc) do
    {:error, {:ell_decryption_failed, Enum.reverse(error_acc)}}
  end

  defp try_decrypt_and_verify(bin, icb, [key | keys], error_acc) do
    with {:ok, <<payload_crc::little-size(16), rest::binary>>} <- decrypt_aes_ctr(bin, icb, key),
         {:ok, plain} <- verify_crc(payload_crc, rest) do
      {:ok, plain}
    else
      {:error, reason} ->
        try_decrypt_and_verify(bin, icb, keys, [%{key: key, reason: reason} | error_acc])
    end
  end

  # defp encrypt_aes_ctr(bin, icb, key),
  #   do: Exmbus.Crypto.crypto_one_time(:aes_ctr, key, icb, bin, true)

  defp decrypt_aes_ctr(bin, icb, key),
    do: Exmbus.Crypto.crypto_one_time(:aes_ctr, key, icb, bin, false)

  defp verify_crc(payload_crc, plain) when is_integer(payload_crc) and is_binary(plain) do
    case Exmbus.crc!(plain) do
      ^payload_crc ->
        {:ok, plain}

      bad_payload_crc ->
        {:error, {:bad_payload_crc, bad_payload_crc}}
    end
  end

  defp identity_from_ctx(%{
         dll: %Exmbus.Parser.Dll.Wmbus{
           manufacturer: m,
           identification_no: i,
           version: v,
           device: d
         }
       }) do
    {:ok, m_bytes} = Manufacturer.encode(m)
    {:ok, i_bytes} = DataType.encode_type_a(i, 32)
    {:ok, d_byte} = Device.encode(d)
    {:ok, <<m_bytes::binary, i_bytes::binary, v, d_byte::binary>>}
  end

  defp identity_from_ctx(%{}) do
    {:error, :could_not_find_identity}
  end
end
