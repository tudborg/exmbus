defmodule Exmbus.Apl do

  alias Exmbus.Apl.DataRecord

  defstruct [
    records: [],
    manufacturer_data: nil
  ]

  @doc """
  Decode the Application Layer and return an %Apl{} struct.

  The Application Layer consists of N number of records where N >= 0,
  and some optional manufacturer specific data.

  The function assumes that the entire input is the APL layer data.

  """
  def decode(bin) do
    decode(bin, [])
  end

  defp decode(<<>>, acc) do
    # no more APL data
    {:ok, %__MODULE__{records: :lists.reverse(acc)}}
  end
  defp decode(bin, acc) do
    case DataRecord.decode(bin) do
      {:ok, record, rest} ->
        decode(rest, [record | acc])
      # just skip the idle filler
      {:special_function, :idle_filler, rest} ->
        decode(rest, acc)
      # manufacturer specific data is the rest of the APL data
      {:special_function, {:manufacturer_specific, :to_end}, rest} ->
        {:ok, %__MODULE__{records: :lists.reverse(acc), manufacturer_data: rest}}
    end
  end

end
