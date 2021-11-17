defmodule Exmbus.Apl.CompactFrame do
  alias Exmbus.Apl.FormatFrame
  alias Exmbus.Apl.FullFrame
  alias Exmbus.Apl.DataRecord
  alias Exmbus.Apl.DataRecord.Header

  defstruct [
    format_signature: nil,
    full_frame_crc: nil,
    data_bytes: nil,
  ]

  def parse(<<format_signature::little-size(16), full_frame_crc::little-size(16), rest::binary>>, _opts, ctx) do
    {:ok,
      [%__MODULE__{
        format_signature: format_signature,
        full_frame_crc: full_frame_crc,
        data_bytes: rest,
        } | ctx], <<>>}
  end

  def expand(%{format_frame_lookup: f}=opts, [%__MODULE__{format_signature: fos, data_bytes: b} | _]=ctx) when is_function(f, 2) do
    case f.(fos, opts) do
      {:ok, %FormatFrame{headers: headers}} ->
        _expand(headers, b, opts, ctx)
    end
  end
  def expand(%{}=opts, ctx) do
    raise "No format_frame_lookup function given as option, got: #{inspect opts} for context: #{inspect ctx}"
  end

  def _expand([], <<>>, _opts, ctx) do
    {rev_records, [%__MODULE__{full_frame_crc: ffc} | ctx]} =
      ctx
      |> Enum.split_while(fn
        %DataRecord{} -> true
        _ -> false
      end)
    full_frame =
      %FullFrame{
        records: Enum.reverse(rev_records),
        manufacturer_bytes: <<>>,
      }
    # assert that the full frame CRC from the compact frame, and the calculated
    # CRC from the constructed FullFrame, matches.
    # This is overly expensive to do because we have to unparse the context to
    # calculate the full frame crc, but for correctness, let's do this.
    # we can optimize later.
    {:ok, ^ffc} = FullFrame.full_frame_crc(full_frame)

    {:ok, [full_frame | ctx]}
  end
  def _expand([%Header{}=header | headers], bytes, opts, ctx) do
    case DataRecord.parse_data(header, bytes) do
      {:ok, data, rest} ->
        _expand(headers, rest, opts, [%DataRecord{header: header, data: data} | ctx])
      {:error, _reason, _rest}=e ->
        e
    end
  end
end
