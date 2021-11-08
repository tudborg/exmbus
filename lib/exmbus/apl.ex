defmodule Exmbus.Apl do

  alias Exmbus.Apl.DataRecord
  alias Exmbus.Tpl
  alias Exmbus.Key
  alias Exmbus.Dll.Wmbus
  alias Exmbus.Manufacturer
  alias Exmbus.Tpl.Device
  alias Exmbus.DataType

  defstruct [
    records: [],
    manufacturer_data: nil,
  ]

  defmodule Encrypted do
    @moduledoc """
    Used to signify that the APL was encrypted and no key was supplied
    """
    defstruct [
      encrypted_bytes: nil,
      plain_bytes: nil,
      mode: nil,
      iv: nil,
    ]
  end

  @doc """
  Decode the Application Layer and return an %Apl{} struct.

  The Application Layer consists of N number of records where N >= 0,
  and some optional manufacturer specific data.

  The function assumes that the entire input is the APL layer data.

  """
  def parse(bin, opts, [%Tpl{}=tpl|_]=parsed) do
    case Tpl.encrypted?(tpl) do
      true -> parse_encrypted(bin, opts, parsed)
      false -> parse_unencrypted(bin, opts, parsed)
    end
  end
  # if TPL isn't the previous layer then treat it as not encrypted
  def parse(bin, opts, parsed) do
    parse_unencrypted(bin, opts, parsed)
  end

  defp parse_unencrypted(bin, _opts, parsed) do
    {:ok, {records, manufacturer_data}} = parse_records(bin, [])
    apl = %__MODULE__{
      records: records,
      manufacturer_data: manufacturer_data,
    }
    {:ok, [apl | parsed]}
  end

  defp parse_records(<<>>, acc) do
    # no more APL data
    {:ok, {:lists.reverse(acc), <<>>}}
  end
  defp parse_records(bin, acc) do
    case DataRecord.parse(bin) do
      {:ok, record, rest} ->
        parse_records(rest, [record | acc])
      # just skip the idle filler
      {:special_function, :idle_filler, rest} ->
        parse_records(rest, acc)
      # manufacturer specific data is the rest of the APL data
      {:special_function, {:manufacturer_specific, :to_end}, rest} ->
        {:ok, {:lists.reverse(acc), rest}}
    end
  end

  defp parse_encrypted(bin, opts, [%Tpl{}=tpl | _]=parsed) do
    mode = Tpl.encryption_mode(tpl)
    {enc, plain} = split_encrypted(bin, tpl)
    {:ok, iv} = case mode do
      {:mode, 5} -> layers_to_mode_5_iv(parsed)
    end
    encrypted_apl = %Encrypted{
      encrypted_bytes: enc,
      plain_bytes: plain,
      mode: mode,
      iv: iv,
    }
    # If we have a Key option set, try parsing with that,
    # otherwise, return the current parse stack back to the user.
    # we cannot continue any further without a key.
    case Map.get(opts, :key) do
      %Key{}=key ->
        parse_encrypted_with_key(key, opts, [encrypted_apl | parsed])
      nil ->
        {:ok, [encrypted_apl | parsed]}
    end
  end

  defp parse_encrypted_with_key(%Key{}=key, opts, [%Encrypted{mode: {:mode, 5}, iv: iv, encrypted_bytes: enc, plain_bytes: plain} | parsed]) do
    # TODO handle multiple possible keys
    {:ok, [byte_key]} = Key.keys_for_parse_stack(key, opts, parsed)
    case :crypto.block_decrypt(:aes_cbc, byte_key, iv, enc) do
      <<0x2f, 0x2f, _::binary>>=decrypted ->
        parse_unencrypted(<<decrypted::binary, plain::binary>>, opts, parsed)
      _ ->
        {:error, {:invalid_key, byte_key}}
    end
  end



  #####################
  # Encryption helpers
  #####################

  # split APL bytes into two an encrypted and plain part based on tpl header, {encrypted, plain}
  defp split_encrypted(apl_bytes, tpl) do
    len = Tpl.encrypted_byte_count(tpl)
    <<enc::binary-size(len), plain::binary>> = apl_bytes
    {enc, plain}
  end

  # Generate the IV for mode 5 encryption
  defp layers_to_mode_5_iv([%Tpl{header: %Tpl.Short{access_no: a_no}}, %Wmbus{}=wmbus | _]) do
    %Wmbus{manufacturer: m, identification_no: i, version: v, device: d} = wmbus
    {:ok, man_bytes} = Manufacturer.encode(m)
    {:ok, id_bytes} = DataType.encode_type_a(i, 32)
    device_byte = Device.encode(d)
    {:ok, <<man_bytes::binary, id_bytes::binary, v, device_byte::binary,
            a_no, a_no, a_no, a_no, a_no, a_no, a_no, a_no>>}
  end
  defp layers_to_mode_5_iv([%Tpl{header: %Tpl.Long{}=header} | _]) do
    %Tpl.Long{manufacturer: m, identification_no: id, version: v, device: d, access_no: a_no} = header
    {:ok, man_bytes} = Manufacturer.encode(m)
    {:ok, id_bytes} = DataType.encode_type_a(id, 32)
    device_byte = Device.encode(d)
    {:ok, <<man_bytes::binary, id_bytes::binary, v, device_byte::binary,
            a_no, a_no, a_no, a_no, a_no, a_no, a_no, a_no>>}
  end


end
