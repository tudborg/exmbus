
defmodule Exmbus.Apl.DataRecord do
  alias Exmbus.Apl.DataRecord
  alias Exmbus.Apl.DataRecord.Header
  alias Exmbus.DataType

  defstruct [
    # header is the Header struct
    header: nil,
    # data is the data decoded based on the structure described in the header
    data: nil,
  ]

  @doc """
  Decodes a single DataRecord from a binary.
  """
  @spec parse(binary())
    :: {:ok, %__MODULE__{}, rest :: binary()}
    |  Header.DataInformationBlock.special_function()
  def parse(bin) do
    case Header.parse(bin) do
      {:ok, header, rest} ->
        # parse data from rest
        case parse_data(header, rest) do
          {:ok, data, rest} ->
            {:ok, %__MODULE__{header: header, data: data}, rest}
          {:error, _reason, _rest}=e ->
            e
        end
      # see Exmbus.Apl.DataRecord.DataInformationBlock for more on what
      # this is. But it's basically signal bytes and seperators disguised as DataInformationBlocks.
      # really annoying that we have to bubble them all the way up to APL, but it's the
      # only place that should know about what to do about them.
      {:special_function, _type, _rest}=s ->
        s
    end
  end

  @doc """
  Retrieve the value of the DataRecord.
  This is the raising version of value/1
  """
  def value!(dr) do
    case value(dr) do
      {:ok, value} -> value
      # TODO handle error
    end
  end

  @doc """
  Retrieve the value of the DataRecord.
  The value is calculated from the decoded data, modified with added extensions
  found in the header.
  """
  @spec value(%DataRecord{}) :: {:ok, value :: term()} | {:error, reason :: term()}
  # The trivial case, no extensions, no multiplier. The data is the data.
  def value(%DataRecord{header: %{extensions: [], multiplier: nil}, data: data}), do: data
  # Also easy case, no extensions, a multiplier exists and data is numerical:
  def value(%DataRecord{header: %{extensions: [], multiplier: mul}, data: data}) when is_number(data), do: mul * data

  @doc """
  Returns the unit for a DataRecord as a string.
  This string will have any relevant extensions added it to, so it might differ from the
  raw unit in the header's Value Information Block.
  """
  # easy case, no extensions. The unit is the unit.
  def unit(%DataRecord{header: %{extensions: [], unit: unit}}), do: unit


  @doc """
  decodes a value associated with a given header.
  """
  # No data:
  def parse_data(%{coding: :no_data, size: 0}, bin), do: {:ok, :no_data, bin}
  # Selection for readout:
  def parse_data(%{coding: :selection_for_readout, size: 0}, bin), do: {:ok, :selection_for_readout, bin}
  # BCD of any size (Type A)
  def parse_data(%{data_type: :type_a, size: size}, bin), do: DataType.decode_type_a(bin, size)
  # Signed integer (Type B)
  def parse_data(%{data_type: :type_b, size: size}, bin), do: DataType.decode_type_b(bin, size)
  # Unsigned integer (Type C)
  def parse_data(%{data_type: :type_c, size: size}, bin), do: DataType.decode_type_c(bin, size)
  # Boolean (bit array) (Type D)
  def parse_data(%{data_type: :type_d, size: size}, bin), do: DataType.decode_type_d(bin, size)
  # Datetime 32bit (Type F)
  def parse_data(%{data_type: :type_f, size: 32}, bin), do: DataType.decode_type_f(bin)
  # Date (Type G)
  def parse_data(%{data_type: :type_g, size: 16}, bin), do: DataType.decode_type_g(bin)
  # Real 32 bit (Type H)
  def parse_data(%{data_type: :type_h, size: 32}, bin), do: DataType.decode_type_h(bin)
  # Datetime 48 bit (Type I)
  def parse_data(%{data_type: :type_i, size: 48}, bin), do: DataType.decode_type_i(bin)
  # Time 24 bit (Type J)
  def parse_data(%{data_type: :type_j, size: 24}, bin), do: DataType.decode_type_j(bin)
  # Datetime in LVAR (Type M)
  def parse_data(%{data_type: :type_m, size: :lvar}, bin), do: DataType.decode_type_m(bin)
  # Variable length coding (LVAR)
  def parse_data(%{coding: :variable_length, size: :lvar}, bin), do: DataType.decode_lvar(bin)

end
