defmodule Exmbus.Tpl do
  @moduledoc """
  Module responsible for handling the transport layer.
  Primarily described in EN 13757-7:2018.

  See also the Exmbus.CI module.
  """

  alias Exmbus.DataType
  alias Exmbus.Apl
  alias Exmbus.Tpl.Device
  alias Exmbus.Tpl.Status
  alias Exmbus.Tpl.ConfigurationField

  defstruct [
    ci: nil,
    header: nil,
    apl: nil,
  ]

  defmodule None do
    defstruct [
    ]
  end
  defmodule Short do
    defstruct [
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
  @spec decode(binary()) :: {:ok, %__MODULE__{}, rest :: binary()} | {:error, {:ci, integer()} | reason :: any()}
  ##
  ## format frames:
  ##
  # none
  def decode(<<0x69, rest::binary>>), do: raise "TODO: MBus format frame tpl header=none"
  # short
  def decode(<<0x6A, rest::binary>>), do: raise "TODO: MBus format frame tpl header=short"
  # long
  def decode(<<0x6B, rest::binary>>), do: raise "TODO: MBus format frame tpl header=long"

  ##
  ## Full frames:
  ##
  # MBus full frame none
  def decode(<<0x78, rest::binary>>), do: raise "TODO: MBus fill frame tpl header=none"
  # MBus full frame short
  def decode(<<0x7A, rest::binary>>), do: raise "TODO: MBus fill frame tpl header=short"
  # MBus full frame long
  def decode(<<0x72, rest::binary>>) do
    {:ok, header, rest} = decode_tpl_header_long(rest)
    case header.configuration_field.mode do
      0 -> # no TPL layer encryption, we can parse rest as APL
        case Apl.decode(rest) do
          {:ok, apl} ->
            tpl = %__MODULE__{
              header: header,
              apl: apl,
              ci: 0x72,
            }
            {:ok, tpl, <<>>}
        end
    end
  end

  # MBus compact long
  def decode(<<0x73, rest::binary>>), do: raise "TODO: MBus compact frame tpl header=long"
  # MBus compact none
  def decode(<<0x79, rest::binary>>), do: raise "TODO: MBus compact frame tpl header=none"
  # MBus compact short
  def decode(<<0x7B, rest::binary>>), do: raise "TODO: MBus compact frame tpl header=short"




  ##
  ## Helpers
  ##


  # TPL header decoders
  def decode_tpl_header_short(bin) do
    raise "TODO"
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
  def decode_tpl_header_long(<<ident_bytes::binary-size(4), man::little-size(16),
                                version, device_byte::binary-size(1), access_no,
                                status_byte::binary-size(1), rest::binary>>) do
    # the ident_bytes is 32 bits of BCD (Type A):
    {:ok, identification_no, <<>>} = DataType.decode_type_a(ident_bytes, 32)
    status = Status.decode(status_byte)
    device = Device.decode(device_byte)
    {:ok, configuration_field, rest} = ConfigurationField.decode(rest)
    header = %Long{
      identification_no: identification_no,
      manufacturer: int_to_manufacturer(man),
      version: version,
      device: device,
      access_no: access_no,
      status: status,
      configuration_field: configuration_field,
    }
    {:ok, header, rest}
  end

  # TODO handle wildcard manufacturer 0xFFFF ? EN 13757-7:2018 section 7.5.2 Manufacturer identification
  def int_to_manufacturer(n) when is_integer(n) do
    <<a::size(5), b::size(5), c::size(5)>> = <<n::15>>
    <<(a+64), (b+64), (c+64)>>
  end
  def manufacturer_to_int(<<a,b,c>>) do
    (a-64) * 32 * 32 +
    (b-64) * 32 +
    (c-64)
  end

end
