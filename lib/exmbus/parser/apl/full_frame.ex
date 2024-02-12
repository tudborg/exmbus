defmodule Exmbus.Parser.Apl.FullFrame do
  alias Exmbus.Parser.Context
  alias Exmbus.Parser.Apl.DataRecord.InvalidDataRecord
  alias Exmbus.Parser.Apl.DataRecord
  alias Exmbus.Parser.Apl.FormatFrame

  defstruct records: [],
            manufacturer_bytes: nil

  def parse(bin, opts, ctx) do
    parse_full_frame(bin, opts, ctx, [])
  end

  defp parse_full_frame(<<>>, opts, ctx, acc) do
    finalize_full_frame(<<>>, opts, ctx, acc)
  end

  defp parse_full_frame(bin, opts, ctx, acc) do
    case DataRecord.parse(bin, opts, ctx) do
      {:ok, %DataRecord{} = data_record, rest} ->
        parse_full_frame(rest, opts, ctx, [data_record | acc])

      {:ok, %InvalidDataRecord{} = data_record, rest} ->
        parse_full_frame(rest, opts, ctx, [data_record | acc])

      # just skip the idle filler
      {:special_function, :idle_filler, rest} ->
        parse_full_frame(rest, opts, ctx, acc)

      # manufacturer specific data is the rest of the APL data
      {:special_function, {:manufacturer_specific, :to_end}, rest} ->
        finalize_full_frame(rest, opts, ctx, acc)

      {:special_function, {:manufacturer_specific, :more_records_follow}, rest} ->
        finalize_full_frame(rest, opts, ctx, acc)

      {:error, _reason, _rest} = e ->
        e
    end
  end

  defp finalize_full_frame(rest, _opts, ctx, acc) do
    full_frame = %__MODULE__{
      records: Enum.reverse(acc),
      manufacturer_bytes: rest
    }

    {:ok, Context.layer(ctx, :apl, full_frame), <<>>}
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
end
