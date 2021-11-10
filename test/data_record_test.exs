defmodule DataRecordTest do
  use ExUnit.Case

  alias Exmbus.Apl.DataRecord
  alias Exmbus.Apl.DataRecord.Header

  doctest Exmbus.Apl.DataRecord, import: true

  describe "Main VIFE-code extension table (0xFD)" do
    test "0bE0010111 Error flags" do
      {:ok, record, <<0xFF, 0xFF>>} = DataRecord.parse(<<0x02, 0xfd, 0x17, 0b00000100, 0b10000000, 0xFF, 0xFF>>, %{}, [])

      assert %DataRecord{
        data: [true, false, false, false, false, false, false, false,
              false, false, false, false, false, true, false, false],
        header: %Header{
          data_type: :type_d,
          description: :error_flags,
          size: 16,
        }
      } = record
    end
  end

  describe "Regression: ABB-style energy reading" do
    record = %Exmbus.Apl.DataRecord{
      data: 455224,
      header: %Exmbus.Apl.DataRecord.Header{
        coding: :bcd,
        data_type: :type_a,
        description: :energy,
        device: 0,
        extensions: [record_error: :none],
        function_field: :instantaneous,
        multiplier: 10,
        size: 48,
        storage: 0,
        tariff: 0,
        unit: "Wh"
      }
    }

    assert %{value: 4552240, unit: "Wh"} = DataRecord.to_map!(record)
  end
end
