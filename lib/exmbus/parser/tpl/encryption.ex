defmodule Exmbus.Parser.Tpl.Encryption do
  @behaviour Exmbus.Parser.ParseBehaviour

  alias Exmbus.Parser.Context
  alias Exmbus.Key
  alias Exmbus.Parser.Dll.Wmbus
  alias Exmbus.Parser.Tpl
  alias Exmbus.Parser.Tpl.Device
  alias Exmbus.Parser.DataType
  alias Exmbus.Parser.Manufacturer

  @doc """
  "Parse" the encryption layer of the TPL.

  This function will decrypt the encrypted bytes according to the TPL encryption mode.
  We name it `parse` because it follows the `ParseBehaviour` interface.
  """
  def parse(%{tpl: tpl} = ctx) do
    decrypt_to_context(Tpl.encryption_mode(tpl), ctx)
  end

  defp decrypt_to_context(0, ctx) do
    {:continue, ctx}
  end

  defp decrypt_to_context(5, ctx) do
    {:ok, encrypted_byte_count} = Tpl.encrypted_byte_count(ctx.tpl)
    <<encrypted::binary-size(encrypted_byte_count), plain::binary>> = ctx.rest

    case decrypt_mode_5(encrypted, ctx) do
      {:ok, decrypted} ->
        {:continue, Context.merge(ctx, rest: <<decrypted::binary, plain::binary>>)}

      {:error, reason} ->
        {:abort, Context.add_error(ctx, reason)}
    end
  end

  defp decrypt_to_context(mode, ctx) do
    {:abort, Context.add_error(ctx, {:unknown_encryption_mode, mode})}
  end

  # decrypt mode 5 bytes
  # Decrypt the encrypted_bytes according to mode 5 encryption.
  # The context is required to get the keys, and build the IV.
  defp decrypt_mode_5(encrypted_bytes, ctx) do
    {:ok, iv} = ctx_to_mode_5_iv(ctx)

    with {:ok, byte_keys} <- Key.get(ctx) do
      answer =
        Enum.find_value(byte_keys, fn
          byte_key when byte_size(byte_key) == 16 ->
            case Exmbus.Crypto.crypto_one_time(:aes_cbc, byte_key, iv, encrypted_bytes, false) do
              # Valid key, decrypts with marker 0x2F2F:
              {:ok, <<0x2F, 0x2F, rest::binary>>} -> {:ok, rest}
              # Not valid key, marker not found as prefix:
              {:ok, _other} -> nil
              # decryption error:
              {:error, e} -> {:error, {:mode_5_decryption_failed, e}}
            end

          byte_key ->
            {:error, {:invalid_key, {:not_16_bytes, byte_key}}, ctx}
        end)

      case answer do
        {:ok, _bin} = ok -> ok
        {:error, _reason, _ctx} = e -> e
        nil -> {:error, {:mode_5_decryption_failed, byte_keys}, ctx}
      end
    else
      {:error, e} ->
        {:error, e, ctx}
    end
  end

  # Generate the IV for mode 5 encryption
  defp ctx_to_mode_5_iv(%{tpl: %Tpl{header: %Tpl.Short{} = header}, dll: %Wmbus{} = wmbus}) do
    mode_5_iv(
      wmbus.manufacturer,
      wmbus.identification_no,
      wmbus.version,
      wmbus.device,
      header.access_no
    )
  end

  defp ctx_to_mode_5_iv(%{tpl: %Tpl{header: %Tpl.Long{} = header}}) do
    mode_5_iv(
      header.manufacturer,
      header.identification_no,
      header.version,
      header.device,
      header.access_no
    )
  end

  defp mode_5_iv(manufacturer, identification_no, version, device, access_no) do
    {:ok, man_bytes} = Manufacturer.encode(manufacturer)
    {:ok, id_bytes} = DataType.encode_type_a(identification_no, 32)
    {:ok, device_byte} = Device.encode(device)

    {:ok,
     <<man_bytes::binary, id_bytes::binary, version, device_byte::binary, access_no, access_no,
       access_no, access_no, access_no, access_no, access_no, access_no>>}
  end
end
