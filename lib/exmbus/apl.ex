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

    iex> decode(<<0b00000001, 0b00000011, 42, 0b01000001, 0b00000011, 62>>)
    {:ok, %Apl{
      manufacturer_data: nil,
      records: [
        %Apl.DataRecord{
          data: 42,
          header: %Apl.DataRecord.Header{
            dib: %Apl.DataRecord.DataInformationBlock{
              function_field: :instantaneous,
              coding: :int,
              size: 8,
              device: 0,
              tariff: 0,
              storage: 0,
            },
            vib: %Apl.DataRecord.ValueInformationBlock{
              description: :energy,
              extensions: [],
              multiplier: 1,
              unit: "Wh",
            }
          }
        },
        %Apl.DataRecord{
          data: 62,
          header: %Apl.DataRecord.Header{
            dib: %Apl.DataRecord.DataInformationBlock{
              function_field: :instantaneous,
              coding: :int,
              size: 8,
              device: 0,
              tariff: 0,
              storage: 1,
            },
            vib: %Apl.DataRecord.ValueInformationBlock{
              description: :energy,
              extensions: [],
              multiplier: 1,
              unit: "Wh",
            }
          }
        }
      ]
    }}

    iex> decode(<<0x2F, 0x2F, 0x0F, 0x2F, 0x12, 0x34>>)
    {:ok, %Apl{
        manufacturer_data: <<0x2F, 0x12, 0x34>>,
        records: [],
    }}
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
