
defmodule Exmbus.Apl.DataRecord do
  alias Exmbus.Apl.DataRecord
  alias Exmbus.Apl.DataRecord.Header
  alias Exmbus.Apl.DataRecord.DataType

  defstruct [
    # header is the Header struct
    header: nil,
    # data is the raw data decoded based on the structure described in header
    data: nil,
  ]

  @doc """
  Decodes a single DataRecord from a binary.

    #dif, 8 bit int, vif, energy NNN=3, data=42
    iex> decode(<<0b00000001, 0b00000011, 42, 0xFF>>)
    {:ok, %DataRecord{
      header:  %Header{
        dib: %DataInformationBlock{
          coding: :int,
          device: 0,
          function_field: :instantaneous,
          size: 8,
          storage: 0,
          tariff: 0
        },
        vib: %ValueInformationBlock{
          description: :energy,
          extensions: [],
          multiplier: 1,
          unit: "Wh"
        }
      },
      data: 42
    }, <<0xFF>>}

    iex> decode(<<0x2F, 0xFF>>)
    {:special_function, :idle_filler, <<0xFF>>}

    iex> decode(<<0x0F, 0xFF>>)
    {:special_function, {:manufacturer_specific, :to_end}, <<0xFF>>}

  """
  @spec decode(binary())
    :: {:ok, %__MODULE__{}, rest :: binary()}
    |  Header.DataInformationBlock.special_function()
  def decode(bin) do
    case Header.decode(bin) do
      {:ok, header, rest} ->
        # decode data from rest
        case decode_data(header, rest) do
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
  def value(%DataRecord{header: %{vib: %{extensions: [], multiplier: nil}}, data: data}), do: data
  # Also easy case, no extensions, a multiplier exists and data is numerical:
  def value(%DataRecord{header: %{vib: %{extensions: [], multiplier: mul}}, data: data}) when is_number(data), do: mul * data

  @doc """
  Returns the unit for a DataRecord as a string.
  This string will have any relevant extensions added it to, so it might differ from the
  raw unit in the header's Value Information Block.
  """
  # easy case, no extensions. The unit is the unit.
  def unit(%DataRecord{header: %{vib: %{extensions: [], unit: unit}}}), do: unit


  @doc """
  decodes a value associated with a given header.
  """
  # No data:
  def decode_data(%{dib: %{coding: :no_data, size: 0}}, bin), do: {:ok, :no_data, bin}
  # Selection for readout:
  def decode_data(%{dib: %{coding: :selection_for_readout, size: 0}}, bin), do: {:ok, :selection_for_readout, bin}
  # BCD of any size (Type A)
  def decode_data(%{dib: %{coding: :bcd, size: size}}, bin), do: DataType.decode_type_a(bin, size)
  # Date (Type G)
  def decode_data(%{vib: %{description: :date}, dib: %{coding: :int, size: 16}}, bin), do: DataType.decode_type_g(bin)
  # (Date)Time, depending on size, uses Type F, J, I or M
  def decode_data(%{vib: %{description: :datetime}, dib: %{coding: :int, size: 32}}, bin), do: DataType.decode_type_f(bin)
  def decode_data(%{vib: %{description: :datetime}, dib: %{coding: :int, size: 24}}, bin), do: DataType.decode_type_j(bin)
  def decode_data(%{vib: %{description: :datetime}, dib: %{coding: :int, size: 48}}, bin), do: DataType.decode_type_i(bin)
  def decode_data(%{vib: %{description: :datetime}, dib: %{size: :lvar}}, bin), do: DataType.decode_type_m(bin)
  # Int/Binary (default is signed int, no override by VIF/VIFE)
  def decode_data(%{dib: %{coding: :int, size: size}}, bin), do: DataType.decode_type_b(bin, size)
  # Real
  def decode_data(%{dib: %{coding: :real, size: 32}}, bin), do: DataType.decode_type_h(bin)
  # variable length coding (LVAR)
  def decode_data(%{dib: %{coding: :variable_length, size: :lvar}}, bin), do: DataType.decode_lvar(bin)

end
