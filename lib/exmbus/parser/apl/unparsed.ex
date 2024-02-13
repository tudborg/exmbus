defmodule Exmbus.Parser.Apl.Unparsed do
  @moduledoc """
  Contains the raw APL and encryption mode.
  This struct is usually an intermedidate struct
  and will not show in the final parse stack unless options are given
  to not parse the APL.
  """
  alias Exmbus.Key
  alias Exmbus.Parser.Dll.Wmbus
  alias Exmbus.Parser.Tpl.Device
  alias Exmbus.Parser.DataType
  alias Exmbus.Parser.Manufacturer
  alias Exmbus.Parser.Context
  alias Exmbus.Parser.Tpl

  defstruct encrypted_bytes: nil,
            plain_bytes: nil,
            mode: nil

  def parse(bin, _opts, %{tpl: %Tpl{} = tpl} = ctx) do
    {:mode, m} = Tpl.encryption_mode(tpl)
    {:ok, enclen} = Tpl.encrypted_byte_count(tpl)
    <<enc::binary-size(enclen), plain::binary>> = bin
    apl = %__MODULE__{mode: m, encrypted_bytes: enc, plain_bytes: plain}
    {:ok, Context.layer(ctx, :apl, apl), ""}
  end

  def parse(bin, _opts, ctx) do
    apl = %__MODULE__{mode: 0, encrypted_bytes: <<>>, plain_bytes: bin}
    {:ok, Context.layer(ctx, :apl, apl), ""}
  end

  @doc """
  Given a context with an APL set, return a context with APL set, but guaranteed not encrypted.
  If the existing APL is already decrypted, this function returns the context as-is.
  """

  def decrypt(_opts, %{apl: %__MODULE__{mode: 0, plain_bytes: _bin, encrypted_bytes: <<>>}} = ctx) do
    {:ok, ctx}
  end

  def decrypt(opts, %{apl: %__MODULE__{mode: mode}} = ctx)
      when not is_map_key(opts, :key) and mode > 0 do
    {:error, Context.add_error(ctx, {:could_not_decrypt_apl, {:missing_option, :key}})}
  end

  def decrypt(opts, %{apl: %__MODULE__{mode: 5, encrypted_bytes: enc, plain_bytes: plain}} = ctx) do
    case decrypt_mode_5(enc, opts, ctx) do
      {:ok, decrypted} ->
        apl = %__MODULE__{
          mode: 0,
          plain_bytes: <<decrypted::binary, plain::binary>>,
          encrypted_bytes: <<>>
        }

        {:ok, Context.layer(ctx, :apl, apl)}

      {:error, reason} ->
        {:error, Context.add_error(ctx, {:could_not_decrypt_apl, reason})}
    end
  end

  # decrypt mode 5 bytes
  defp decrypt_mode_5(enc, opts, ctx) do
    {:ok, iv} = ctx_to_mode_5_iv(ctx)

    with {:ok, byte_keys} <- Key.get(opts, ctx) do
      answer =
        Enum.find_value(byte_keys, fn
          byte_key when byte_size(byte_key) == 16 ->
            case :crypto.crypto_one_time(:aes_cbc, byte_key, iv, enc, false) do
              <<0x2F, 0x2F, rest::binary>> -> {:ok, rest}
              # not the valid key
              _ -> nil
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
