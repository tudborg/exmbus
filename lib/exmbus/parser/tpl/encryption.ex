defmodule Exmbus.Parser.Tpl.Encryption do
  @moduledoc """
  This module handles the encryption of the TPL layer.
  """

  alias Exmbus.Key
  alias Exmbus.Parser.Context
  alias Exmbus.Parser.Dll.Wmbus
  alias Exmbus.Parser.IdentificationNo
  alias Exmbus.Parser.Manufacturer
  alias Exmbus.Parser.Tpl
  alias Exmbus.Parser.Tpl.Device

  @doc """
  decrypts the context data according to the TPL layer.

  This function will decrypt the encrypted bytes according to the TPL encryption mode.
  """
  def decrypt_bin(%{tpl: nil} = ctx), do: {:next, ctx}
  def decrypt_bin(%{tpl: tpl} = ctx), do: decrypt_to_context(encryption_mode(tpl), ctx)

  @doc """
  Return configured encryption mode as {:mode, m}
  """
  def encryption_mode(%Tpl{header: header}), do: encryption_mode(header)
  def encryption_mode(%Tpl.Header.None{}), do: 0
  def encryption_mode(%Tpl.Header.Short{configuration_field: %{mode: m}}), do: m
  def encryption_mode(%Tpl.Header.Long{configuration_field: %{mode: m}}), do: m

  @doc """
  Is tpl encrypted?
  """
  def encrypted?(%Tpl{header: header}), do: encrypted?(header)
  def encrypted?(%Tpl.Header.None{}), do: false
  def encrypted?(%Tpl.Header.Short{configuration_field: %{mode: 0}}), do: false
  def encrypted?(%Tpl.Header.Short{configuration_field: %{mode: _}}), do: true
  def encrypted?(%Tpl.Header.Long{configuration_field: %{mode: 0}}), do: false
  def encrypted?(%Tpl.Header.Long{configuration_field: %{mode: _}}), do: true

  @doc """
  Get the number of expected encrypted bytes in the APL binary
  """
  def encrypted_byte_count(%Tpl{header: header}), do: encrypted_byte_count(header)
  def encrypted_byte_count(%Tpl.Header.None{}), do: {:ok, 0}

  def encrypted_byte_count(%Tpl.Header.Short{configuration_field: %{mode: m, blocks: n}})
      when m != 0,
      do: {:ok, n * 16}

  def encrypted_byte_count(%Tpl.Header.Long{configuration_field: %{mode: m, blocks: n}})
      when m != 0,
      do: {:ok, n * 16}

  # when mode is 0, then encrypted byte count is 0
  def encrypted_byte_count(%Tpl.Header.Short{configuration_field: %{mode: 0}}), do: {:ok, 0}
  def encrypted_byte_count(%Tpl.Header.Long{configuration_field: %{mode: 0}}), do: {:ok, 0}

  defp decrypt_to_context(0, ctx) do
    {:next, ctx}
  end

  defp decrypt_to_context(5, ctx) do
    {:ok, encrypted_byte_count} = encrypted_byte_count(ctx.tpl)
    <<encrypted::binary-size(encrypted_byte_count), plain::binary>> = ctx.bin

    {:ok, iv} = ctx_to_mode_5_iv(ctx)

    with {:ok, byte_keys} <- Key.get(ctx),
         {:ok, decrypted} <- decrypt_mode_5(encrypted, byte_keys, iv) do
      {:next, %{ctx | bin: <<decrypted::binary, plain::binary>>}}
    else
      {:error, reason} ->
        {:halt, Context.add_error(ctx, reason)}
    end
  end

  defp decrypt_to_context(mode, ctx) do
    {:halt, Context.add_error(ctx, {:unknown_encryption_mode, mode})}
  end

  # decrypt mode 5 bytes
  # Decrypt the encrypted_bytes according to mode 5 encryption.
  # The context is required to get the keys, and build the IV.
  defp decrypt_mode_5(encrypted_bytes, byte_keys, iv) do
    answer =
      Enum.find_value(byte_keys, fn
        byte_key when byte_size(byte_key) == 16 ->
          case Exmbus.Crypto.crypto_one_time(:aes_cbc, byte_key, iv, encrypted_bytes, false) do
            # Valid key, decrypts with marker 0x2F2F:
            {:ok, <<0x2F, 0x2F, rest::binary>>} -> {:ok, rest}
            # Not valid key, marker not found as prefix:
            {:ok, _other} -> nil
            # decryption error:
            {:error, e} -> {:error, {:mode_5_decryption, {:decrypt_failed, e}}}
          end

        byte_key ->
          {:error, {:invalid_key, {:not_16_bytes, byte_key}}}
      end)

    case answer do
      {:ok, _bin} = ok -> ok
      {:error, _reason, _ctx} = e -> e
      nil -> {:error, {:mode_5_decryption, {:no_valid_key, {:tried, length(byte_keys)}}}}
    end
  end

  # Generate the IV for mode 5 encryption
  defp ctx_to_mode_5_iv(%{tpl: %Tpl{header: %Tpl.Header.Short{} = header}, dll: %Wmbus{} = wmbus}) do
    mode_5_iv(
      wmbus.manufacturer,
      wmbus.identification_no,
      wmbus.version,
      wmbus.device,
      header.access_no
    )
  end

  defp ctx_to_mode_5_iv(%{tpl: %Tpl{header: %Tpl.Header.Long{} = header}}) do
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
    {:ok, id_bytes} = IdentificationNo.encode(identification_no)
    {:ok, device_byte} = Device.encode(device)

    {:ok,
     <<man_bytes::binary, id_bytes::binary, version, device_byte::binary, access_no, access_no,
       access_no, access_no, access_no, access_no, access_no, access_no>>}
  end
end
