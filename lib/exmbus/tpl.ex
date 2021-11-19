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
  ]

  ##
  ## TPL Header structs
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
  Parses a transport layer and adds it to the parse context.
  This function will return an error if the first byte
  is not a CI field describing a transport layer.
  """
  @spec parse(binary(), [any()], [map()]) :: {:ok, [map()]} | {:error, {:ci, integer()} | (reason :: any())}
  ##
  ## format frames:
  ##
  # none
  def parse(<<0x69, rest::binary>>, opts, ctx) do
    finalize_tpl(:format_frame, %None{}, rest, opts, ctx)
  end
  # short
  def parse(<<0x6A, _rest::binary>>, _opts, _ctx), do: raise "TODO: MBus format frame tpl header=short"
  # long
  def parse(<<0x6B, _rest::binary>>, _opts, _ctx), do: raise "TODO: MBus format frame tpl header=long"

  ##
  ## Full frames:
  ##
  # MBus full frame none
  def parse(<<0x78, rest::binary>>, opts, ctx) do
    finalize_tpl(:full_frame, %None{}, rest, opts, ctx)
  end
  # MBus full frame short
  def parse(<<0x7A, rest::binary>>, opts, ctx) do
    {:ok, header, rest} = parse_tpl_header_short(rest)
    finalize_tpl(:full_frame, header, rest, opts, ctx)
  end
  # MBus full frame long
  def parse(<<0x72, rest::binary>>, opts, ctx) do
    {:ok, header, rest} = parse_tpl_header_long(rest)
    finalize_tpl(:full_frame, header, rest, opts, ctx)
  end

  # MBus compact long
  def parse(<<0x73, rest::binary>>, opts, ctx) do
    {:ok, header, rest} = parse_tpl_header_long(rest)
    finalize_tpl(:compact_frame, header, rest, opts, ctx)
  end
  # MBus compact none
  def parse(<<0x79, rest::binary>>, opts, ctx) do
    finalize_tpl(:compact_frame, %None{}, rest, opts, ctx)
  end
  # MBus compact short
  def parse(<<0x7B, rest::binary>>, opts, ctx) do
    {:ok, header, rest} = parse_tpl_header_short(rest)
    finalize_tpl(:compact_frame, header, rest, opts, ctx)
  end



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
  def encrypted_byte_count(%None{}), do: {:ok, 0}
  def encrypted_byte_count(%Short{configuration_field: %{mode: m, blocks: n}}) when m != 0, do: {:ok, n * 16}
  def encrypted_byte_count(%Long{configuration_field: %{mode: m, blocks: n}}) when m != 0, do: {:ok, n * 16}
  # when mode is 0, then encrypted byte count is 0
  def encrypted_byte_count(%Short{configuration_field: %{mode: 0}}), do: {:ok, 0}
  def encrypted_byte_count(%Long{configuration_field: %{mode: 0}}), do: {:ok, 0}

  ##
  ## Helpers
  ##

  # decode APL layer after decoding TPL header and figuring out encryption mode and frame type
  defp finalize_tpl(frame_type, header, rest, opts, ctx) do
    tpl = %__MODULE__{
      frame_type: frame_type,
      header: header,
    }
    Apl.parse(rest, opts, [tpl | ctx])
  end

  # TPL header decoders
  # NOTE, rest contains the Configuration Field but we can't parse it out becaise
  # it might have extensions, so we leave the parsing to ConfigurationField.decode/1
  def parse_tpl_header_short(<<access_no, status_byte::binary-size(1), rest::binary>>) do
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

    iex> parse_tpl_header_long(<<0x78,0x56,0x34,0x12,0x93,0x15,0x33,0x03,0x2A,0x00,0x00,0x00,0xFF,0xFF>>)
    {:ok, %Exmbus.Tpl.Long{
      identification_no: 12345678,
      manufacturer: "ELS",
      version: 51,
      device: :gas,
      access_no: 42,
      status: %Exmbus.Tpl.Status{},
      configuration_field: %Exmbus.Tpl.ConfigurationField{},
    }, <<0xFF, 0xFF>>}
  """
  # NOTE, rest contains the Configuration Field but we can't parse it out becaise
  # it might have extensions, so we leave the parsing to ConfigurationField.decode/1
  def parse_tpl_header_long(<<ident_bytes::binary-size(4), man_bytes::binary-size(2),
                                version, device_byte::binary-size(1), access_no,
                                status_byte::binary-size(1), rest::binary>>) do
    # the ident_bytes is 32 bits of BCD (Type A):
    {:ok, identification_no, <<>>} = DataType.decode_type_a(ident_bytes, 32)
    status = Status.decode(status_byte)
    {:ok, device} = Device.decode(device_byte)
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
