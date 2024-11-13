defmodule Exmbus.Parser.Apl.FullFrame do
  alias Exmbus.Parser.Context
  alias Exmbus.Parser.Apl.DataRecord.InvalidDataRecord
  alias Exmbus.Parser.Apl.DataRecord
  alias Exmbus.Parser.Apl.FormatFrame

  defstruct records: [],
            manufacturer_bytes: nil

  def parse(%Context{} = ctx) do
    parse_full_frame(ctx, [])
  end

  defp parse_full_frame(%{bin: <<>>} = ctx, acc) do
    finalize_full_frame(ctx, acc)
  end

  defp parse_full_frame(ctx, acc) do
    case DataRecord.parse(ctx.bin, ctx.opts, ctx) do
      {:ok, %DataRecord{} = data_record, rest} ->
        parse_full_frame(Context.merge(ctx, bin: rest), [data_record | acc])

      {:ok, %InvalidDataRecord{} = data_record, rest} ->
        parse_full_frame(Context.merge(ctx, bin: rest), [data_record | acc])

      # just skip the idle filler
      {:special_function, :idle_filler, rest} ->
        parse_full_frame(Context.merge(ctx, bin: rest), acc)

      # manufacturer specific data is the rest of the APL data
      {:special_function, {:manufacturer_specific, :to_end}, rest} ->
        finalize_full_frame(Context.merge(ctx, bin: rest), acc)

      {:special_function, {:manufacturer_specific, :more_records_follow}, rest} ->
        finalize_full_frame(Context.merge(ctx, bin: rest), acc)

      {:error, _reason, _rest} = e ->
        e
    end
  end

  defp finalize_full_frame(%{} = ctx, acc) do
    full_frame = %__MODULE__{
      records: Enum.reverse(acc),
      # all remaining bytes are manufacturer specific:
      manufacturer_bytes: ctx.bin
    }

    {:next, Context.merge(ctx, bin: <<>>, apl: full_frame)}
  end

  def format_signature(%__MODULE__{} = ff) do
    ff
    |> FormatFrame.from_full_frame!()
    |> FormatFrame.format_signature()
  end

  def full_frame_crc(%__MODULE__{records: records, manufacturer_bytes: <<>>}) do
    record_bytes =
      records
      |> Enum.map(fn record ->
        {:ok, bytes} = DataRecord.unparse(%{}, record)
        bytes
      end)
      |> Enum.into("")

    {:ok, Exmbus.crc!(record_bytes)}
  end

  @doc """
  This function will expand compact profiles in the APL unless the option `expand_compact_profiles` is false.
  """
  def maybe_expand_compact_profiles(%{opts: %{expand_compact_profiles: false}} = ctx) do
    {:next, ctx}
  end

  def maybe_expand_compact_profiles(%{apl: %{records: []}} = ctx) do
    {:next, ctx}
  end

  def maybe_expand_compact_profiles(ctx) do
    expand_compact_profiles(ctx)
  end

  def expand_compact_profiles(%{apl: %__MODULE__{records: records}} = ctx) do
    records
    |> Enum.filter(&DataRecord.is_compact_profile?/1)
    |> Enum.reduce({:next, ctx}, fn
      compact_profile_record, {:next, ctx} ->
        case DataRecord.expand_compact_profile(compact_profile_record, ctx) do
          {:ok, ctx} -> {:next, ctx}
          {:error, reason} -> {:next, Context.add_warning(ctx, reason)}
        end

      _compact_profile_record, {:halt, ctx} ->
        {:halt, ctx}
    end)
  end
end
