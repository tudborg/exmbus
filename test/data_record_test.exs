defmodule DataRecordTest do
  use ExUnit.Case, async: true

  alias Exmbus.Parser.Context
  alias Exmbus.Parser.Apl.DataRecord
  alias Exmbus.Parser.Apl.DataRecord.Header
  alias Exmbus.Parser.Apl.DataRecord.DataInformationBlock
  alias Exmbus.Parser.Apl.DataRecord.ValueInformationBlock

  doctest Exmbus.Parser.Apl.DataRecord, import: true

  describe "Main VIFE-code extension table (0xFD)" do
    test "0bE0010111 Error flags" do
      {:ok, record, <<0xFF, 0xFF>>} =
        DataRecord.parse(
          <<0x02, 0xFD, 0x17, 0b00000100, 0b10000000, 0xFF, 0xFF>>,
          %{},
          Context.new()
        )

      assert %DataRecord{
               data: [
                 true,
                 false,
                 false,
                 false,
                 false,
                 false,
                 false,
                 false,
                 false,
                 false,
                 false,
                 false,
                 false,
                 true,
                 false,
                 false
               ],
               header: %Header{
                 dib: %DataInformationBlock{
                   size: 16
                 },
                 vib: %ValueInformationBlock{
                   coding: :type_d,
                   description: :error_flags
                 }
               }
             } = record
    end
  end

  test "Regression: ABB-style energy reading" do
    record = %DataRecord{
      data: 455_224,
      header: %DataRecord.Header{
        dib: %DataInformationBlock{
          device: 0,
          storage: 0,
          tariff: 0,
          function_field: :instantaneous,
          data_type: :bcd,
          size: 48
        },
        vib: %ValueInformationBlock{
          coding: :type_a,
          description: :energy,
          extensions: [record_error: :none],
          multiplier: 10,
          unit: "Wh"
        }
      }
    }

    assert %{value: 4_552_240, unit: "Wh"} = DataRecord.to_map!(record)
  end
end
