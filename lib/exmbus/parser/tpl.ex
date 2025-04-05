defmodule Exmbus.Parser.Tpl do
  @moduledoc """
  Module responsible for handling the transport layer.
  Primarily described in EN 13757-7:2018.

  See also the Exmbus.Parser.CI module.
  """

  alias Exmbus.Parser.IdentificationNo
  alias Exmbus.Parser.CI
  alias Exmbus.Parser.Context
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
  def parse(ctx) do
    # Allow only TPL and APL CI codes.
    # If if hit an ELL, AFL or similar, we error out.
    case CI.lookup(ctx.bin) do
      # cowardly refusing to parse manufacturer specific CI
      {:ok, {_layer, :manufacturer_specific} = l} ->
        {:halt, Context.add_error(ctx, {:unexpected_ci, l})}

      {:ok, {:tpl, _layer_ext}} ->
        _parse(ctx)

      {:ok, {:apl, _layer_ext}} ->
        _parse(ctx)

      {:ok, {_layer, _layer_ext} = l} ->
        {:halt, Context.add_error(ctx, {:unexpected_ci, l})}

      {:error, reason} ->
        {:halt, Context.add_error(ctx, reason)}
    end
  end

  ##
  ## Format frames:
  ##
  # none
  def _parse(%{bin: <<0x69, rest::binary>>} = ctx) do
    finalize_tpl(:format_frame, %None{}, rest, ctx)
  end

  # short
  def _parse(%{bin: <<0x6A, rest::binary>>} = ctx) do
    case parse_tpl_header_short(rest) do
      {:ok, header, rest} ->
        finalize_tpl(:format_frame, header, rest, ctx)
        # NOTE: short header cannot currently return error,
        # so dialyzer will complain if we try to handle an error from it:
        # {:error, reason} -> {:halt, Context.add_error(ctx, reason)}
    end
  end

  # long
  def _parse(%{bin: <<0x6B, rest::binary>>} = ctx) do
    {:ok, header, rest} = parse_tpl_header_long(rest)
    finalize_tpl(:format_frame, header, rest, ctx)
  end

  ##
  ## Full frames:
  ##
  # MBus full frame none
  def _parse(%{bin: <<0x78, rest::binary>>} = ctx) do
    finalize_tpl(:full_frame, %None{}, rest, ctx)
  end

  # MBus full frame short
  def _parse(%{bin: <<0x7A, rest::binary>>} = ctx) do
    case parse_tpl_header_short(rest) do
      {:ok, header, rest} ->
        finalize_tpl(:full_frame, header, rest, ctx)
        # NOTE: short header cannot currently return error,
        # so dialyzer will complain if we try to handle an error from it:
        # {:error, reason} -> {:halt, Context.add_error(ctx, reason)}
    end
  end

  # MBus full frame long
  def _parse(%{bin: <<0x72, rest::binary>>} = ctx) do
    {:ok, header, rest} = parse_tpl_header_long(rest)
    finalize_tpl(:full_frame, header, rest, ctx)
  end

  ##
  ## Compact frames:
  ##

  # MBus compact long
  def _parse(%{bin: <<0x73, rest::binary>>} = ctx) do
    {:ok, header, rest} = parse_tpl_header_long(rest)
    finalize_tpl(:compact_frame, header, rest, ctx)
  end

  # MBus compact none
  def _parse(%{bin: <<0x79, rest::binary>>} = ctx) do
    finalize_tpl(:compact_frame, %None{}, rest, ctx)
  end

  # MBus compact short
  def _parse(%{bin: <<0x7B, rest::binary>>} = ctx) do
    case parse_tpl_header_short(rest) do
      {:ok, header, rest} ->
        finalize_tpl(:compact_frame, header, rest, ctx)
        # NOTE: short header cannot currently return error,
        # so dialyzer will complain if we try to handle an error from it:
        # {:error, reason} -> {:halt, Context.add_error(ctx, reason)}
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
  defp parse_tpl_header_short(
         <<access_no, status_byte::binary-size(1), cf_bytes::binary-size(2), rest::binary>>
       ) do
    # NOTE: this decode currently does not return {:error, _}
    case ConfigurationField.decode(cf_bytes) do
      {:ok, configuration_field} ->
        header = %Short{
          access_no: access_no,
          status: Status.decode(status_byte),
          configuration_field: configuration_field
        }

        {:ok, header, rest}
    end
  end

  @doc """
  Decode a TPL long header.

    iex> parse_tpl_header_long(<<0x78,0x56,0x34,0x12,0x93,0x15,0x33,0x03,0x2A,0x00,0x00,0x00,0xFF,0xFF>>)
    {:ok, %Exmbus.Parser.Tpl.Header.Long{
      identification_no: "12345678",
      manufacturer: "ELS",
      version: 51,
      device: %Exmbus.Parser.Tpl.Device{id: 0x03},
      access_no: 42,
      status: %Exmbus.Parser.Tpl.Status{},
      configuration_field: %Exmbus.Parser.Tpl.ConfigurationField{},
    }, <<0xFF, 0xFF>>}
  """
  def parse_tpl_header_long(
        <<ident_bytes::binary-size(4), man_bytes::binary-size(2), version,
          device_byte::binary-size(1), access_no, status_byte::binary-size(1),
          cf_bytes::binary-size(2), rest::binary>>
      ) do
    with {:ok, identification_no} <- IdentificationNo.decode(ident_bytes),
         {:ok, device} <- Device.decode(device_byte),
         {:ok, manufacturer} <- Manufacturer.decode(man_bytes),
         {:ok, configuration_field} <- ConfigurationField.decode(cf_bytes) do
      header = %Long{
        identification_no: identification_no,
        manufacturer: manufacturer,
        version: version,
        device: device,
        access_no: access_no,
        status: Status.decode(status_byte),
        configuration_field: configuration_field
      }

      {:ok, header, rest}
    else
      {:error, reason} ->
        {:error, reason, rest}
    end
  end
end
