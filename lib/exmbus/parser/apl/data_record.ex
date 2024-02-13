defmodule Exmbus.Parser.Apl.DataRecord do
  alias Exmbus.Parser.Apl.DataRecord.CompactProfile
  alias Exmbus.Parser.Apl.DataRecord
  alias Exmbus.Parser.Apl.DataRecord.Header
  alias Exmbus.Parser.Apl.DataRecord.Header.InvalidHeader
  alias Exmbus.Parser.Apl.DataRecord.ValueInformationBlock, as: VIB
  # alias Exmbus.Parser.Apl.DataRecord.DataInformationBlock, as: DIB
  alias Exmbus.Parser.DataType

  defdelegate is_compact_profile?(data_record), to: CompactProfile
  defdelegate expand_compact_profile(data_record, ctx), to: CompactProfile
  defdelegate compact_profile_records(data_record, all_records), to: CompactProfile

  defstruct [
    # header is the Header struct
    header: nil,
    # data is the data decoded based on the structure described in the header
    data: nil
  ]

  defmodule InvalidDataRecord do
    defstruct header: nil,
              data: nil
  end

  @doc """
  Decodes a single DataRecord from a binary.
  """
  def parse(bin, opts, ctx) do
    case Header.parse(bin, opts, ctx) do
      {:ok, %Header{} = header, rest} ->
        case parse_data(header, rest) do
          {:ok, data, rest} ->
            {:ok, %__MODULE__{header: header, data: data}, rest}

          {:error, {:cannot_parse_data, _}, _rest} = e ->
            e
        end

      # see Exmbus.Parser.Apl.DataRecord.DataInformationBlock for more on what
      # this is. But it's basically signal bytes and seperators disguised as DataInformationBlocks.
      # really annoying that we have to bubble them all the way up to APL, but it's the
      # only place that should know about what to do about them.
      {:special_function, _type, _rest} = s ->
        s

      {:ok, %InvalidHeader{} = header, rest} ->
        case consume_data(header, rest) do
          {:ok, raw, rest} ->
            {:ok, %InvalidDataRecord{header: header, data: raw}, rest}
        end
    end
  end

  def unparse(opts, %__MODULE__{header: h, data: d}) do
    with {:ok, h_bytes} <- Header.unparse(opts, h),
         {:ok, d_bytes} <- unparse_data(h, d) do
      {:ok, <<h_bytes::binary, d_bytes::binary>>}
    end
  end

  @doc """
  Retrieve the simplified value of the DataRecord.
  The value is calculated from the decoded data, modified with added extensions
  found in the header.
  """
  @spec value(%DataRecord{}) :: {:ok, value :: term()} | {:error, reason :: term()}
  def value(%DataRecord{header: _, data: {:invalid, _}}) do
    {:ok, :invalid}
  end

  def value(%DataRecord{
        header: %{vib: %{extensions: vib_extensions, multiplier: mul}},
        data: data
      }) do
    try do
      value =
        data
        |> value_vib_multiplier(mul)
        |> value_vib_extensions(vib_extensions)

      {:ok, value}
    catch
      {:error, _} = e -> e
    end
  end

  # The trivial case, no extensions, no multiplier. The data is the data.
  def value(%DataRecord{header: %{vib: %{extensions: [], multiplier: nil}}, data: data}) do
    {:ok, data}
  end

  # Also easy case, no extensions, a multiplier exists and data is numerical:
  def value(%DataRecord{header: %{vib: %{extensions: [], multiplier: mul}}, data: data})
      when is_number(data) do
    {:ok, mul * data}
  end

  def value(
        %DataRecord{header: %{vib: %{extensions: [{:record_error, :none} | tail]} = vib} = header} =
          dr
      ) do
    # We ignore a record_error: :none
    value(%{dr | header: %{header | vib: %{vib | extensions: tail}}})
  end

  # If we have unknown extensions:
  def value(%DataRecord{header: %{vib: %{extensions: [ext | _]}}}) do
    {:error, {:unhandled_extension, ext}}
  end

  defp value_vib_multiplier(value, nil), do: value
  defp value_vib_multiplier(value, mul), do: value * mul

  defp value_vib_extensions(value, []), do: value

  defp value_vib_extensions(value, [{:multiplicative_correction_factor, factor} | rest]),
    do: value_vib_extensions(value * factor, rest)

  defp value_vib_extensions(value, [{:additive_correction_constant, constant} | rest]),
    do: value_vib_extensions(value + constant, rest)

  defp value_vib_extensions(value, [{:record_error, :none} | rest]),
    do: value_vib_extensions(value, rest)

  defp value_vib_extensions(_value, [{:record_error, _} = reason | _rest]),
    do: throw({:error, reason})

  # We ignore rest of extensions
  defp value_vib_extensions(value, [_ | rest]), do: value_vib_extensions(value, rest)

  def value!(record) do
    case value(record) do
      {:ok, value} ->
        value

      {:error, reason} ->
        raise "could not get value from DataRecord, reason=#{inspect(reason)} record=#{inspect(record)}"
    end
  end

  @doc """
  Returns the unit for a DataRecord as a string.
  This string will have any relevant extensions added it to, so it might differ from the
  raw unit in the header's Value Information Block.
  """
  # easy case, no extensions. The unit is the unit.
  def unit(%DataRecord{header: %{vib: vib}}) do
    unit(vib)
  end

  def unit(%VIB{extensions: exts, unit: unit}) do
    try do
      unit =
        unit
        |> unit_vib_extensions(exts)

      {:ok, unit}
    catch
      {:error, _} = e -> e
    end
  end

  def unit!(record) do
    case unit(record) do
      {:ok, unit} ->
        unit

      {:error, reason} ->
        raise "could not get unit from DataRecord, reason=#{inspect(reason)} record=#{inspect(record)}"
    end
  end

  defp unit_vib_extensions(unit, []), do: unit

  defp unit_vib_extensions(unit, [{:record_error, :none} | rest]),
    do: unit_vib_extensions(unit, rest)

  defp unit_vib_extensions(_unit, [{:record_error, _} = reason | _rest]),
    do: throw({:error, reason})

  defp unit_vib_extensions(unit, [{:per, :interval, i} | rest]),
    do: unit_vib_extensions("#{unit}/#{interval_to_string(i)}", rest)

  defp unit_vib_extensions(unit, [{:per, :unit, u} | rest]),
    do: unit_vib_extensions("#{unit}/#{u}", rest)

  defp unit_vib_extensions(unit, [{:multiplied_by, u} | rest]),
    do: unit_vib_extensions("#{unit}#{u}", rest)

  # NOTE: we ignore rest of extensions
  defp unit_vib_extensions(unit, [_ | rest]), do: unit_vib_extensions(unit, rest)

  defp interval_to_string(:second), do: "s"
  defp interval_to_string(:minute), do: "min"
  defp interval_to_string(:hour), do: "h"
  defp interval_to_string(:day), do: "day"
  defp interval_to_string(:month), do: "month"
  defp interval_to_string(:year), do: "year"

  def to_map!(%DataRecord{header: header} = dr) do
    unit =
      case unit(dr) do
        {:ok, u} ->
          u
      end

    value =
      case value(dr) do
        {:ok, v} ->
          v
      end

    %{
      unit: unit,
      value: value,
      device: header.dib.device,
      tariff: header.dib.tariff,
      storage: header.dib.storage,
      function_field: header.dib.function_field,
      description: header.vib.description,
      extensions: header.vib.extensions
    }
  end

  defp consume_data(%InvalidHeader{dib: %{size: size}}, bin) do
    s = div(size, 8)
    <<head::binary-size(s), rest::binary>> = bin
    {:ok, head, rest}
  end

  @doc """
  decodes a value associated with a given header.
  """
  # No data:
  def parse_data(%{dib: %{data_type: :no_data, size: 0}}, bin), do: {:ok, :no_data, bin}
  # Selection for readout:
  def parse_data(%{dib: %{data_type: :selection_for_readout, size: 0}}, bin),
    do: {:ok, :selection_for_readout, bin}

  # Size is > 0 but bin is zero. No data to parse, invalid.
  def parse_data(%{dib: %{size: size}} = header, <<>>) when size > 0,
    do: {:error, {:cannot_parse_data, header}, <<>>}

  # BCD of any size (Type A)
  def parse_data(%{coding: :type_a, dib: %{size: size}}, bin),
    do: DataType.decode_type_a(bin, size)

  # Signed integer (Type B)
  def parse_data(%{coding: :type_b, dib: %{size: size}}, bin),
    do: DataType.decode_type_b(bin, size)

  # Unsigned integer (Type C)
  def parse_data(%{coding: :type_c, dib: %{size: size}}, bin),
    do: DataType.decode_type_c(bin, size)

  # Boolean (bit array) (Type D)
  def parse_data(%{coding: :type_d, dib: %{size: size}}, bin),
    do: DataType.decode_type_d(bin, size)

  # Datetime 32bit (Type F)
  def parse_data(%{coding: :type_f, dib: %{size: 32}}, bin), do: DataType.decode_type_f(bin)
  # Date (Type G)
  def parse_data(%{coding: :type_g, dib: %{size: 16}}, bin), do: DataType.decode_type_g(bin)
  # Real 32 bit (Type H)
  def parse_data(%{coding: :type_h, dib: %{size: 32}}, bin), do: DataType.decode_type_h(bin)
  # Datetime 48 bit (Type I)
  def parse_data(%{coding: :type_i, dib: %{size: 48}}, bin), do: DataType.decode_type_i(bin)
  # Time 24 bit (Type J)
  def parse_data(%{coding: :type_j, dib: %{size: 24}}, bin), do: DataType.decode_type_j(bin)
  # Datetime in LVAR (Type M)
  def parse_data(%{coding: :type_m, dib: %{size: :variable_length}}, bin),
    do: DataType.decode_type_m(bin)

  # Variable length data_type (LVAR)
  def parse_data(%{dib: %{size: :variable_length}}, bin), do: DataType.decode_lvar(bin)

  # No data:
  def unparse_data(%{dib: %{data_type: :no_data, size: 0}}, :no_data), do: {:ok, <<>>}
  # Selection for readout:
  def unparse_data(%{dib: %{data_type: :selection_for_readout, size: 0}}, :selection_for_readout),
    do: {:ok, <<>>}

  # BCD of any size (Type A)
  def unparse_data(%{coding: :type_a, dib: %{size: size}}, data),
    do: DataType.encode_type_a(data, size)

  # Signed integer (Type B)
  def unparse_data(%{coding: :type_b, dib: %{size: size}}, data),
    do: DataType.encode_type_b(data, size)

  # Unsigned integer (Type C)
  def unparse_data(%{coding: :type_c, dib: %{size: size}}, data),
    do: DataType.encode_type_c(data, size)

  # Boolean (bit array) (Type D)
  def unparse_data(%{coding: :type_d, dib: %{size: size}}, data),
    do: DataType.encode_type_d(data, size)

  # Datetime 32bit (Type F)
  def unparse_data(%{coding: :type_f, dib: %{size: 32}}, data), do: DataType.encode_type_f(data)
  # Date (Type G)
  def unparse_data(%{coding: :type_g, dib: %{size: 16}}, data), do: DataType.encode_type_g(data)
  # Real 32 bit (Type H)
  def unparse_data(%{coding: :type_h, dib: %{size: 32}}, data), do: DataType.encode_type_h(data)
  # Datetime 48 bit (Type I)
  def unparse_data(%{coding: :type_i, dib: %{size: 48}}, data), do: DataType.encode_type_i(data)
  # Time 24 bit (Type J)
  def unparse_data(%{coding: :type_j, dib: %{size: 24}}, data), do: DataType.encode_type_j(data)
  # Datetime in LVAR (Type M)
  def unparse_data(%{coding: :type_m, dib: %{size: :variable_length}}, data),
    do: DataType.encode_type_m(data)

  # Variable length data_type (LVAR)
  def unparse_data(%{dib: %{size: :variable_length}}, data), do: DataType.encode_lvar(data)
end
