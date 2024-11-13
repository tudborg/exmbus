defmodule Exmbus.Parser.Tpl do
  @moduledoc """
  Module responsible for handling the transport layer.
  Primarily described in EN 13757-7:2018.

  See also the Exmbus.Parser.CI module.
  """

  alias Exmbus.Parser.Context
  alias Exmbus.Parser.DataType
  alias Exmbus.Parser.Manufacturer
  alias Exmbus.Parser.Tpl.Device
  alias Exmbus.Parser.Tpl.Status
  alias Exmbus.Parser.Tpl.ConfigurationField
  alias Exmbus.Parser.Tpl.Encryption
  alias Exmbus.Parser.Tpl.Header.None
  alias Exmbus.Parser.Tpl.Header.Short
  alias Exmbus.Parser.Tpl.Header.Long

  @type t :: %__MODULE__{
          frame_type: :format_frame | :full_frame | :compact_frame,
          header: None.t() | Short.t() | Long.t()
        }

  defstruct frame_type: nil,
            header: nil

  @doc """
  Parses a transport layer and adds it to the parse context.
  This function will return an error if the first byte
  is not a CI field describing a transport layer.
  """

  ##
  ## Format frames:
  ##
  # none
  def parse(%{bin: <<0x69, rest::binary>>} = ctx) do
    finalize_tpl(:format_frame, %None{}, rest, ctx)
  end

  # short
  def parse(%{bin: <<0x6A, rest::binary>>} = ctx) do
    with {:ok, header, rest} <- parse_tpl_header_short(rest) do
      finalize_tpl(:format_frame, header, rest, ctx)
    else
      {:error, reason} -> {:halt, Context.add_error(ctx, reason)}
    end
  end

  # long
  def parse(%{bin: <<0x6B, rest::binary>>} = ctx) do
    {:ok, header, rest} = parse_tpl_header_long(rest)
    finalize_tpl(:format_frame, header, rest, ctx)
  end

  ##
  ## Full frames:
  ##
  # MBus full frame none
  def parse(%{bin: <<0x78, rest::binary>>} = ctx) do
    finalize_tpl(:full_frame, %None{}, rest, ctx)
  end

  # MBus full frame short
  def parse(%{bin: <<0x7A, rest::binary>>} = ctx) do
    with {:ok, header, rest} <- parse_tpl_header_short(rest) do
      finalize_tpl(:full_frame, header, rest, ctx)
    else
      {:error, reason} -> {:halt, Context.add_error(ctx, reason)}
    end
  end

  # MBus full frame long
  def parse(%{bin: <<0x72, rest::binary>>} = ctx) do
    {:ok, header, rest} = parse_tpl_header_long(rest)
    finalize_tpl(:full_frame, header, rest, ctx)
  end

  ##
  ## Compact frames:
  ##

  # MBus compact long
  def parse(%{bin: <<0x73, rest::binary>>} = ctx) do
    {:ok, header, rest} = parse_tpl_header_long(rest)
    finalize_tpl(:compact_frame, header, rest, ctx)
  end

  # MBus compact none
  def parse(%{bin: <<0x79, rest::binary>>} = ctx) do
    finalize_tpl(:compact_frame, %None{}, rest, ctx)
  end

  # MBus compact short
  def parse(%{bin: <<0x7B, rest::binary>>} = ctx) do
    with {:ok, header, rest} <- parse_tpl_header_short(rest) do
      finalize_tpl(:compact_frame, header, rest, ctx)
    else
      {:error, reason} -> {:halt, Context.add_error(ctx, reason)}
    end
  end

  defdelegate decrypt_bin(ctx), to: Encryption

  ##
  ## Helpers
  ##

  # decode APL layer after decoding TPL header and figuring out encryption mode and frame type
  defp finalize_tpl(frame_type, header, rest, ctx) do
    tpl = %__MODULE__{
      frame_type: frame_type,
      header: header
    }

    {:next, %{ctx | bin: rest, tpl: tpl}}
  end

  # TPL header decoders
  # NOTE, rest contains the Configuration Field but we can't parse it out becaise
  # it might have extensions, so we leave the parsing to ConfigurationField.decode/1
  defp parse_tpl_header_short(<<access_no, status_byte::binary-size(1), rest::binary>>) do
    status = Status.decode(status_byte)

    with {:ok, configuration_field, rest} <- ConfigurationField.decode(rest) do
      header = %Short{
        access_no: access_no,
        status: status,
        configuration_field: configuration_field
      }

      {:ok, header, rest}
    else
      {:error, _} = e -> e
    end
  end

  @doc """
  Decode a TPL long header.

    iex> parse_tpl_header_long(<<0x78,0x56,0x34,0x12,0x93,0x15,0x33,0x03,0x2A,0x00,0x00,0x00,0xFF,0xFF>>)
    {:ok, %Exmbus.Parser.Tpl.Header.Long{
      identification_no: 12345678,
      manufacturer: "ELS",
      version: 51,
      device: :gas,
      access_no: 42,
      status: %Exmbus.Parser.Tpl.Status{},
      configuration_field: %Exmbus.Parser.Tpl.ConfigurationField{},
    }, <<0xFF, 0xFF>>}
  """
  # NOTE, rest contains the Configuration Field but we can't parse it out becaise
  # it might have extensions, so we leave the parsing to ConfigurationField.decode/1
  def parse_tpl_header_long(
        <<ident_bytes::binary-size(4), man_bytes::binary-size(2), version,
          device_byte::binary-size(1), access_no, status_byte::binary-size(1), rest::binary>>
      ) do
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
      configuration_field: configuration_field
    }

    {:ok, header, rest}
  end
end
