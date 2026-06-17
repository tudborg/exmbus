defmodule Exmbus.Parser.Apl.FormatFrame do
  @moduledoc """
  Parser for a format frame.

  A FormatFrame contains headers. It can be used on combination with
  a CompactFrame to create a full frame.
  """

  alias Exmbus.Parser.Apl.DataRecord
  alias Exmbus.Parser.Apl.FullFrame
  alias Exmbus.Parser.Context

  @type t :: %__MODULE__{
          headers: list(DataRecord.Header.t())
        }

  defstruct headers: nil

  def parse(%{bin: <<len, format_signature::little-size(16), rest::binary>>} = ctx) do
    _parse_format_frame({len, format_signature}, rest, %{ctx | bin: <<>>}, [])
  end

  defp _parse_format_frame(ff_header, <<>>, ctx, acc) do
    finalize_format_frame(ff_header, <<>>, ctx, acc)
  end

  defp _parse_format_frame(ff_header, bin, ctx, acc) do
    case DataRecord.Header.parse(bin, ctx) do
      {:ok, header, rest} ->
        _parse_format_frame(ff_header, rest, ctx, [header | acc])

      # just skip the idle filler
      {:special_function, :idle_filler, rest} ->
        _parse_format_frame(ff_header, rest, ctx, acc)

      # manufacturer specific data is the rest of the APL data
      {:special_function, {:manufacturer_specific, :to_end}, rest} ->
        finalize_format_frame(ff_header, rest, ctx, acc)

      {:special_function, {:manufacturer_specific, :more_records_follow}, rest} ->
        finalize_format_frame(ff_header, rest, ctx, acc)
    end
  end

  # NOTE: should we check length?
  defp finalize_format_frame({_len, format_signature}, <<>>, ctx, acc) do
    format_frame = %__MODULE__{headers: Enum.reverse(acc)}
    ctx = %{ctx | apl: format_frame}

    if Map.get(ctx.opts, :verify_format_signature, true) do
      case format_signature(format_frame) do
        {:ok, ^format_signature} ->
          {:next, ctx}

        {:ok, differing_format_signature} ->
          {:halt,
           Context.add_error(
             ctx,
             {:format_signature_mismatch,
              %{expected: format_signature, got: differing_format_signature}}
           )}
      end
    else
      {:next, ctx}
    end
  end

  def from_full_frame!(%FullFrame{records: records}) do
    headers =
      records
      |> Enum.map(& &1.header)

    %__MODULE__{headers: headers}
  end

  def format_signature(%__MODULE__{} = frame) do
    frame
    |> to_header_bytes()
    |> format_signature()
  end

  def format_signature(bytes) when is_binary(bytes) do
    {:ok, Exmbus.crc!(bytes)}
  end

  @doc """
  Convert the format frame to bytes.

  This is useful for persisting the format frames or for calculating the format signature.
  """
  @spec to_header_bytes(t()) :: binary()
  def to_header_bytes(%__MODULE__{headers: headers}) when is_list(headers) do
    headers
    |> Enum.map(fn
      # if we have the header bytes collected already, we can use those
      %DataRecord.Header{dib_bytes: d, vib_bytes: v} when is_binary(d) and is_binary(v) ->
        <<d::binary, v::binary>>

      # otherwise we need to try and unparse the headers
      %DataRecord.Header{dib_bytes: d, vib_bytes: v} = header when is_nil(d) or is_nil(v) ->
        {:ok, header_bin} = DataRecord.Header.unparse(header)
        header_bin
    end)
    |> Enum.into("")
  end

  @doc """
  Parse a FormatFrame from header bytes (no length or format signature)

  This is usually required to get a FormatFrame from stored header bytes.
  """
  @spec from_header_bytes(binary()) :: {:ok, t()} | {:error, [any()]}
  def from_header_bytes(bytes) when is_binary(bytes) do
    len = byte_size(bytes)
    ctx = Context.new(opts: %{verify_format_signature: false})

    case _parse_format_frame({len, 0}, bytes, ctx, []) do
      {:next, %{apl: %__MODULE__{} = format_frame}} -> {:ok, format_frame}
      {:halt, %{errors: reasons}} -> {:error, reasons}
    end
  end
end
