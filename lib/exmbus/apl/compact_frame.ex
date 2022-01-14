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

  @doc """
  Given some options and a parsed context with a CompactFrame on top, will expand the
  top CompactFrame struct into a FullFrame struct and return {:ok, [%FullFrame{} | rest]}

  The option :format_frame_fn must be set to a 2-arity function that receives a format signature and
  the remaining options, and return {:ok, %FormatFrame{}}

  The Full-Frame-CRC from the compact frame will be verified against the expanded FullFrame,
  and an error returned if they do not match. This behaviour can be disabled with the option :verify_full_frame_crc
  """
  def expand(%{format_frame_fn: f}=opts, [%__MODULE__{format_signature: fos, data_bytes: data_bytes} | _]=ctx) when is_function(f, 2) do
    case f.(fos, opts) do
      {:ok, %FormatFrame{headers: headers}} ->
        _expand(headers, data_bytes, opts, ctx)
      {:error, reason} ->
        {:error, {:format_frame_lookup_failed, reason}, ctx}
      bad_return ->
        raise "Unexpected return from the format_frame_fn function, expected {:ok, %FormatFrame{}}, got: #{inspect(bad_return)}"
    end
  end
  def expand(%{}=opts, ctx) do
    raise "No format_frame_fn function given as option, got: #{inspect opts} for context: #{inspect ctx}"
  end

  def _expand([], <<>> = _data_bytes, opts, ctx) do
    {rev_records, [%__MODULE__{full_frame_crc: ffc} | rest_ctx]} =
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

    check_result =
      if Map.get(opts, :verify_full_frame_crc, true) do
        # assert that the full frame CRC from the compact frame, and the calculated
        # CRC from the constructed FullFrame, matches.
        # This is overly expensive to do because we have to unparse the context to
        # calculate the full frame crc, but for correctness, let's do this.
        # we can optimize later.
        case FullFrame.full_frame_crc(full_frame) do
          {:ok, ^ffc} ->
            :ok
          {:ok, differing_ffc} ->
            {:error, {:full_frame_crc_mismatch, %{expected: ffc, got: differing_ffc}}, ctx}
        end
      end
    with :ok <- check_result do
      {:ok, [full_frame | rest_ctx]}
    end
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
