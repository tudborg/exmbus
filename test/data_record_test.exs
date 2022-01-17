defmodule DataRecordTest do
  use ExUnit.Case, async: true

  alias Exmbus.Apl.DataRecord
  alias Exmbus.Apl.DataRecord.Header
  alias Exmbus.Apl.DataRecord.DataInformationBlock
  alias Exmbus.Apl.DataRecord.ValueInformationBlock

  doctest Exmbus.Apl.DataRecord, import: true

  describe "Main VIFE-code extension table (0xFD)" do
    test "0bE0010111 Error flags" do
      {:ok, [record], <<0xFF, 0xFF>>} = DataRecord.parse(<<0x02, 0xfd, 0x17, 0b00000100, 0b10000000, 0xFF, 0xFF>>, %{}, [])

      assert %DataRecord{
        data: [true, false, false, false, false, false, false, false,
              false, false, false, false, false, true, false, false],
        header: %Header{
          dib: %DataInformationBlock{
            size: 16,
          },
          vib: %ValueInformationBlock{
            coding: :type_d,
            description: :error_flags,
          },
        }
      } = record
    end
  end

  test "Regression: ABB-style energy reading" do
    record = %Exmbus.Apl.DataRecord{
      data: 455224,
      header: %Exmbus.Apl.DataRecord.Header{
        dib: %DataInformationBlock{
          device: 0,
          storage: 0,
          tariff: 0,
          function_field: :instantaneous,
          data_type: :bcd,
          size: 48,
        },
        vib: %ValueInformationBlock{
          coding: :type_a,
          description: :energy,
          extensions: [record_error: :none],
          multiplier: 10,
          unit: "Wh"
        },
      }
    }

    assert %{value: 4552240, unit: "Wh"} = DataRecord.to_map!(record)
  end
end
