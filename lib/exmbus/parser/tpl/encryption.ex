defmodule Exmbus.Parser.Tpl.Encryption do
  @moduledoc """
  This module handles the encryption of the TPL layer.
  """

  alias Exmbus.Crypto
  alias Exmbus.Parser.Afl
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

  defp decrypt_to_context(7, ctx) do
    {:ok, encrypted_byte_count} = encrypted_byte_count(ctx.tpl)
    <<encrypted::binary-size(encrypted_byte_count), plain::binary>> = ctx.bin

    # Security mode 7 uses AES-128-CBC with an ephemeral key of 128 bits
    # and a static Initialization Vector IV = 0 (16 bytes of 0x00).
    iv = <<0::128>>

    with {:ok, keys} <- keys(ctx, :enc),
         {:ok, decrypted} <- decrypt_mode_5(encrypted, keys, iv) do
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
    default = {:error, {:mode_5_decryption, {:no_valid_key, {:tried, length(byte_keys)}}}}
    # attempt all byte_keys until we find a result.
    # if no result, return the default error.
    Enum.find_value(byte_keys, default, &try_decrypt_mode_5(&1, encrypted_bytes, iv))
  end

  defp try_decrypt_mode_5(key, bytes, iv) when byte_size(key) == 16 do
    case Exmbus.Crypto.crypto_one_time(:aes_cbc, key, iv, bytes, false) do
      # Valid key, decrypts with marker 0x2F2F:
      {:ok, <<0x2F, 0x2F, rest::binary>>} -> {:ok, rest}
      # Not valid key, marker not found as prefix:
      {:ok, _other} -> nil
      # decryption error:
      {:error, e} -> {:error, {:mode_5_decryption, {:decrypt_failed, e}}}
    end
  end

  defp try_decrypt_mode_5(key, _bytes, _iv) when byte_size(key) != 16 do
    {:error, {:invalid_key, {:not_16_bytes, key}}}
  end

  # Generate the IV for mode 5 encryption
  defp ctx_to_mode_5_iv(%{tpl: %Tpl{header: %Tpl.Header.Short{} = header}, dll: %Wmbus{} = wmbus}) do
    mode_5_iv(wmbus, header.access_no)
  end

  defp ctx_to_mode_5_iv(%{tpl: %Tpl{header: %Tpl.Header.Long{} = header}}) do
    mode_5_iv(header, header.access_no)
  end

  defp mode_5_iv(%{} = meter_id, access_no) do
    {:ok,
     <<encode_meter_id(meter_id)::binary, access_no, access_no, access_no, access_no, access_no,
       access_no, access_no, access_no>>}
  end

  defp encode_meter_id(%{manufacturer: m, identification_no: i, version: v, device: d}) do
    {:ok, man_bytes} = Manufacturer.encode(m)
    {:ok, id_bytes} = IdentificationNo.encode(i)
    {:ok, device_byte} = Device.encode(d)

    <<man_bytes::binary, id_bytes::binary, v, device_byte::binary>>
  end

  @doc """
  Retrieve keys to use in `mode` (either `:enc` or `:mac`).

  This applies the selected KDF to the master key(s) and returns the derived keys.
  """
  def keys(ctx, mode \\ :enc) do
    case key_selection(ctx) do
      # we use the master key directly, no KDF
      :persistent_key ->
        Key.get(ctx)

      # An ephemeral key shall be used which is generated with the
      # Key Derivation Function (KDF) and which is described in 9.6
      :kdf_a ->
        with {:ok, master_keys} <- Key.get(ctx) do
          # The Key Derivation Function shall apply the CMAC-Function according to NIST/SP 800-38B.
          # This Key Derivation Function bases on key expansion procedure of NIST/SP 800–56C.
          # The calculation of key K shall be as follows: K=CMAC(MK,DC||C||ID||07h ||07h ||07h ||07h ||07h ||07h ||07h)
          # where
          #  MK is Message key;
          #  DC is Derivation constant;
          #  C is Message counter;
          #  ID is Meter ID.
          # depending on direction and mode, we pick DC
          {:ok, direction} = Wmbus.direction(ctx.dll)

          # > The KDF requires a Message counter. The KDF shall use the Message counter provided by the TPL.
          counter = find_message_counter(ctx)

          # For messages from the meter to the communication partner which use a short TPL-header, (like CI = 7Ah; see 7.3)
          # the ID corresponds to the Identification Number in the Link Layer Address (see 8.3) of the meter.
          # For messages with long header (like CI = 72h; see 7.4) the ID corresponds to the
          # Application Layer Identification Number (see 7.5.1) of the meter.
          # For messages from the communication partner to the meter the Long Header is always used.
          # The ID corresponds to the Identification Number in the
          # Application Layer Address (see 7.5.1) of the meter (not the communication partner).
          {:ok, meter_id} = IdentificationNo.encode(find_meter_id(ctx).identification_no)
          # derrive the keys
          keys = Enum.map(master_keys, &Crypto.kdf_a!(direction, mode, counter, meter_id, &1))

          {:ok, keys}
        end
    end
  end

  defp find_meter_id(%{tpl: %Tpl{header: %Tpl.Header.Long{} = header}}) do
    header
  end

  defp find_meter_id(%{tpl: %Tpl{header: %Tpl.Header.Short{}}, dll: %Wmbus{} = wmbus}) do
    wmbus
  end

  defp key_selection(%{afl: afl, tpl: tpl}) do
    cond do
      is_struct(afl.ki, KeyInformationField) ->
        Afl.KeyInformationField.kdf(afl.ki)

      is_struct(tpl, Tpl) ->
        case tpl.header do
          %Tpl.Header.Short{configuration_field: cf} ->
            Tpl.ConfigurationField.kdf(cf)

          %Tpl.Header.Long{configuration_field: cf} ->
            Tpl.ConfigurationField.kdf(cf)

          %Tpl.Header.None{} ->
            :persistent_key
        end

      true ->
        :persistent_key
    end
  end

  defp find_message_counter(ctx) do
    # > If no TPL counter is present (bit Z = 0 in configuration field, see Table 33)
    # > then the counter of the AFL (AFL.MCR) shall be used instead.
    cond do
      not is_nil(ctx.tpl.header.configuration_field.counter) ->
        ctx.tpl.header.configuration_field.counter

      is_struct(ctx.afl, Afl) and not is_nil(ctx.afl.mcr) ->
        ctx.afl.mcr
    end
  end
end
