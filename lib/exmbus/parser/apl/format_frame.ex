defmodule Exmbus.Parser.Apl.FormatFrame do
  defstruct headers: nil

  alias Exmbus.Parser.Context
  alias Exmbus.Parser.Apl.FullFrame
  alias Exmbus.Parser.Apl.DataRecord

  def parse(%{bin: <<len, format_signature::little-size(16), rest::binary>>} = ctx) do
    _parse_format_frame({len, format_signature}, rest, ctx, [])
  end

  defp _parse_format_frame(ff_header, <<>>, ctx, acc) do
    finalize_format_frame(ff_header, <<>>, ctx, acc)
  end

  defp _parse_format_frame(ff_header, bin, ctx, acc) do
    case DataRecord.Header.parse(bin, ctx.opts, ctx) do
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

  # TODO: should we check length?
  defp finalize_format_frame({_len, format_signature}, <<>>, ctx, acc) do
    full_frame = %__MODULE__{
      headers: Enum.reverse(acc)
    }

    check_result =
      if Map.get(ctx.opts, :verify_format_signature, true) do
        case format_signature(full_frame) do
          {:ok, ^format_signature} ->
            :ok

          {:ok, differing_format_signature} ->
            {:error,
             {:format_signature_mismatch,
              %{expected: format_signature, got: differing_format_signature}}, ctx}
        end
      end

    with :ok <- check_result do
      {:next, Context.merge(ctx, apl: full_frame, bin: <<>>)}
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
    |> header_bytes()
    |> format_signature()
  end

  def format_signature(bytes) when is_binary(bytes) do
    {:ok, Exmbus.crc!(bytes)}
  end

  defp header_bytes(%__MODULE__{headers: headers}) when is_list(headers) do
    headers
    |> Enum.map(fn
      # if we have the header bytes collected already, we can use those
      %DataRecord.Header{dib_bytes: d, vib_bytes: v} when is_binary(d) and is_binary(v) ->
        <<d::binary, v::binary>>

      # otherwise we need to try and unparse the headers
      %DataRecord.Header{dib_bytes: d, vib_bytes: v} = header when is_nil(d) or is_nil(v) ->
        {:ok, header_bin, []} = DataRecord.Header.unparse(%{}, [header])
        header_bin
    end)
    |> Enum.into("")
  end
end
