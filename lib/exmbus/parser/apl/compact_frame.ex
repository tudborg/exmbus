defmodule Exmbus.Parser.Apl.CompactFrame do
  alias Exmbus.Parser.Context
  alias Exmbus.Parser.Apl.FormatFrame
  alias Exmbus.Parser.Apl.FullFrame
  alias Exmbus.Parser.Apl.DataRecord
  alias Exmbus.Parser.Apl.DataRecord.Header

  defstruct format_signature: nil,
            full_frame_crc: nil,
            data_bytes: nil

  def parse(
        %{
          bin:
            <<format_signature::little-size(16), full_frame_crc::little-size(16), rest::binary>>
        } = ctx
      ) do
    compact_frame = %__MODULE__{
      format_signature: format_signature,
      full_frame_crc: full_frame_crc,
      data_bytes: rest
    }

    {:continue, Context.merge(ctx, apl: compact_frame, bin: <<>>)}
  end

  @doc """
  Given some options and a parsed context with a CompactFrame on top, will expand the
  top CompactFrame struct into a FullFrame struct and return {:ok, [%FullFrame{} | rest]}

  The option :format_frame_fn must be set to a 2-arity function that receives a format signature and
  the remaining options, and return {:ok, %FormatFrame{}}

  The Full-Frame-CRC from the compact frame will be verified against the expanded FullFrame,
  and an error returned if they do not match. This behaviour can be disabled with the option :verify_full_frame_crc
  """
  def expand(
        %{
          apl: %__MODULE__{format_signature: format_signature, data_bytes: data_bytes},
          opts: %{format_frame_fn: f}
        } = ctx
      )
      when is_function(f, 2) do
    case f.(format_signature, ctx.opts) do
      {:ok, %FormatFrame{headers: headers}} ->
        case _expand(headers, data_bytes, ctx, []) do
          {:continue, ctx} -> {:continue, ctx}
          {:abort, ctx} -> {:abort, ctx}
        end

      {:error, reason} ->
        {:abort, Context.add_error(ctx, {:format_frame_lookup_failed, reason})}

      bad_return ->
        raise "Unexpected return from the format_frame_fn function, expected {:ok, %FormatFrame{}}, got: #{inspect(bad_return)}"
    end
  end

  def expand(%{} = ctx) do
    raise "No format_frame_fn function given as option for context: #{inspect(ctx)}"
  end

  def _expand([], <<>> = _data_bytes, ctx, acc) do
    %{apl: %__MODULE__{full_frame_crc: ffc}} = ctx

    full_frame =
      %FullFrame{
        records: Enum.reverse(acc),
        manufacturer_bytes: <<>>
      }

    check_result =
      if Map.get(ctx.opts, :verify_full_frame_crc, true) do
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
      else
        :ok
      end

    case check_result do
      :ok ->
        {:continue, Context.merge(ctx, apl: full_frame, bin: <<>>)}

      {:error, reason} ->
        {:abort, Context.add_error(ctx, reason)}
    end
  end

  def _expand([%Header{} = header | headers], bytes, ctx, acc) do
    case DataRecord.parse_data(header, bytes) do
      {:ok, data, rest} ->
        _expand(headers, rest, ctx, [%DataRecord{header: header, data: data} | acc])

      {:error, reason, rest} ->
        {:abort, Context.add_error(ctx, reason) |> Context.merge(bin: rest)}
    end
  end
end
