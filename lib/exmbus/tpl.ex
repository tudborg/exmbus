defmodule Exmbus.Tpl do
  @moduledoc """
  Module responsible for handling the transport layer.
  Primarily described in EN 13757-7:2018.

  See also the Exmbus.CI module.
  """

  alias Exmbus.DataType
  alias Exmbus.Manufacturer
  alias Exmbus.Apl
  alias Exmbus.Tpl.Device
  alias Exmbus.Tpl.Status
  alias Exmbus.Tpl.ConfigurationField

  defstruct [
    frame_type: nil, # :format_frame | :full_frame | :compact_frame
    header: nil,
    plain_apl: nil, # %Apl{}
    encrypted_apl: nil, # %Apl{} | {:encrypted, binary()}
  ]

  ##
  ## Header structs
  ##
  defmodule None do
    defstruct [
    ]
  end

  defmodule Short do
    defstruct [
      access_no: nil,
      status: nil,
      configuration_field: nil,
    ]
  end

  defmodule Long do
    defstruct [
      identification_no: nil,
      manufacturer: nil,
      version: nil,
      device: nil,
      access_no: nil,
      status: nil,
      configuration_field: nil,
    ]
  end

  @doc """
  Decode a transport layer. This function will return an error if the first byte
  is not a CI field describing a transport layer.
  """
  @spec decode(binary()) :: {:ok, %__MODULE__{}} | {:error, {:ci, integer()} | reason :: any()}
  ##
  ## format frames:
  ##
  def decode(bin, opts \\ [])
  def decode(bin, opts) when is_list(opts) do
    decode(bin, opts |> Enum.into(%{}))
  end
  # none
  def decode(<<0x69, rest::binary>>, _opts), do: raise "TODO: MBus format frame tpl header=none"
  # short
  def decode(<<0x6A, rest::binary>>, _opts), do: raise "TODO: MBus format frame tpl header=short"
  # long
  def decode(<<0x6B, rest::binary>>, _opts), do: raise "TODO: MBus format frame tpl header=long"

  ##
  ## Full frames:
  ##
  # MBus full frame none
  def decode(<<0x78, rest::binary>>, _opts), do: raise "TODO: MBus full frame tpl header=none"
  # MBus full frame short
  def decode(<<0x7A, rest::binary>>, opts) do
    {:ok, header, rest} = decode_tpl_header_short(rest)
    decode_apl(:full_frame, encryption_mode(header), header, rest, opts)
  end
  # MBus full frame long
  def decode(<<0x72, rest::binary>>, opts) do
    {:ok, header, rest} = decode_tpl_header_long(rest)
    decode_apl(:full_frame, encryption_mode(header), header, rest, opts)
  end

  # MBus compact long
  def decode(<<0x73, rest::binary>>, _opts), do: raise "TODO: MBus compact frame tpl header=long"
  # MBus compact none
  def decode(<<0x79, rest::binary>>, _opts), do: raise "TODO: MBus compact frame tpl header=none"
  # MBus compact short
  def decode(<<0x7B, rest::binary>>, _opts), do: raise "TODO: MBus compact frame tpl header=short"



  @doc """
  Return configured encryption mode as {:mode, m}
  """
  def encryption_mode(%__MODULE__{header: header}), do: encryption_mode(header)
  def encryption_mode(%None{}), do: {:mode, 0}
  def encryption_mode(%Short{configuration_field: %{mode: m}}), do: {:mode, m}
  def encryption_mode(%Long{configuration_field: %{mode: m}}), do: {:mode, m}

  @doc """
  Is tpl encrypted?
  """
  def encrypted?(%__MODULE__{header: header}), do: encrypted?(header)
  def encrypted?(%None{}), do: false
  def encrypted?(%Short{configuration_field: %{mode: 0}}), do: false
  def encrypted?(%Short{configuration_field: %{mode: _}}), do: true
  def encrypted?(%Long{configuration_field: %{mode: 0}}), do: false
  def encrypted?(%Long{configuration_field: %{mode: _}}), do: true

  @doc """
  Get the number of expected encrypted bytes in the APL binary
  """
  def encrypted_byte_count(%__MODULE__{header: header}), do: encrypted_byte_count(header)
  def encrypted_byte_count(%None{}), do: 0
  def encrypted_byte_count(%Short{configuration_field: %{mode: m, blocks: n}}) when m != 0, do: n * 16
  def encrypted_byte_count(%Long{configuration_field: %{mode: m, blocks: n}}) when m != 0, do: n * 16

  ##
  ## Helpers
  ##

  # given a header, split APL bytes into two bits, {encrypted, plain}
  defp construct_apl_tuple(header, apl_bytes) do
    len = encrypted_byte_count(header)
    <<enc::binary-size(len), plain::binary>> = apl_bytes
    {enc, plain}
  end

  # decode APL layer after decoding TPL header and figuring out encryption mode and frame type
  defp decode_apl(frame_type, {:mode, 0}, header, rest, opts) do
    case Apl.decode(rest) do
      {:ok, apl} ->
        {:ok, %__MODULE__{
          frame_type: frame_type,
          header: header,
          plain_apl: apl,
          encrypted_apl: nil,
        }}
    end
  end
  defp decode_apl(frame_type, {:mode, 5}=mode, header, rest, %{dll: dll}=opts) do
    keyfn = case opts do
      %{keyfn: keyfn} -> keyfn
      %{} -> raise "frame encrypted but no :keyfn options supplied."
    end
    {enc, plain} = construct_apl_tuple(header, rest)
    {:ok, plain_apl} = Apl.decode(plain)

    {manufacturer, identification_no, version, device, access_no} = case header do
      # if Short header, most info comes from DLL,
      %Short{access_no: access_no} ->
        {dll.manufacturer, dll.identification_no, dll.version, dll.device, access_no}
      # If long, from this header:
      %Long{manufacturer: m, identification_no: id, version: v, device: d, access_no: a} ->
        {m, id, v, d, a}
    end

    {:ok, man_bytes} = Manufacturer.encode(manufacturer)
    {:ok, id_bytes} = DataType.encode_type_a(identification_no, 32)

    iv = << man_bytes::binary, id_bytes::binary, version, device,
            access_no, access_no, access_no, access_no, access_no, access_no, access_no, access_no>>

    case keyfn.(mode, {manufacturer, identification_no, version, device}) do
      {:ok, keys} ->
        case try_mode5_keys(keys, iv, enc) do
          {:error, :no_key} ->
            {:error, {:no_key_match, keys}}
          {:error, reason} ->
            {:error, reason}
          {:ok, _matching_key, data} ->
            {:ok, encrypted_apl} = Apl.decode(data)
            tpl = %__MODULE__{
              frame_type: frame_type,
              header: header,
              plain_apl: plain_apl,
              encrypted_apl: encrypted_apl,
            }
            {:ok, tpl}
        end
      {:error, reason}=e ->
        {:error, {:decode_failed, {:keyfn_return, e}}}
      other ->
        raise "Decoding failed because keyfn (#{inspect keyfn}) was expected to return {:ok, keys} but returned #{inspect other}"
    end
  end

  defp try_mode5_keys([], iv, data), do: {:error, :no_key}
  defp try_mode5_keys([key | ktail], iv, data) when byte_size(key) != 16, do: {:error, {:key_not_16_bytes, key}}
  defp try_mode5_keys([key | ktail], iv, data) do
    case :crypto.block_decrypt(:aes_cbc, key, iv, data) do
      <<0x2f, 0x2f, _::binary>>=decrypted -> {:ok, key, decrypted}
      _ -> try_mode5_keys(ktail, iv, data)
    end
  end



  # TPL header decoders
  # NOTE, rest contains the Configuration Field but we can't parse it out becaise
  # it might have extensions, so we leave the parsing to ConfigurationField.decode/1
  def decode_tpl_header_short(<<access_no, status_byte::binary-size(1), rest::binary>>) do
    status = Status.decode(status_byte)
    {:ok, configuration_field, rest} = ConfigurationField.decode(rest)
    header = %Short{
      access_no: access_no,
      status: status,
      configuration_field: configuration_field,
    }
    {:ok, header, rest}
  end
  @doc """
  Decode a TPL long header.


    iex> decode_tpl_header_long(<<0x78,0x56,0x34,0x12,0x93,0x15,0x33,0x03,0x2A,0x00,0x00,0x00,0xFF,0xFF>>)
    {:ok, %Tpl.Long{
      identification_no: 12345678,
      manufacturer: "ELS",
      version: 51,
      device: :gas,
      access_no: 42,
      status: %Tpl.Status{},
      configuration_field: %Tpl.ConfigurationField{},
    }, <<0xFF, 0xFF>>}
  """
  # NOTE, rest contains the Configuration Field but we can't parse it out becaise
  # it might have extensions, so we leave the parsing to ConfigurationField.decode/1
  def decode_tpl_header_long(<<ident_bytes::binary-size(4), man_bytes::binary-size(2),
                                version, device_byte::binary-size(1), access_no,
                                status_byte::binary-size(1), rest::binary>>) do
    # the ident_bytes is 32 bits of BCD (Type A):
    {:ok, identification_no, <<>>} = DataType.decode_type_a(ident_bytes, 32)
    status = Status.decode(status_byte)
    device = Device.decode(device_byte)
    {:ok, manufacturer} = Manufacturer.decode(man_bytes)
    {:ok, configuration_field, rest} = ConfigurationField.decode(rest)
    header = %Long{
      identification_no: identification_no,
      manufacturer: manufacturer,
      version: version,
      device: device,
      access_no: access_no,
      status: status,
      configuration_field: configuration_field,
    }
    {:ok, header, rest}
  end

end
