defmodule DataRecordTest do
  use ExUnit.Case

  alias Exmbus.Apl.DataRecord
  alias Exmbus.Apl.DataRecord.Header
  alias Exmbus.Apl.DataRecord.DataInformationBlock
  alias Exmbus.Apl.DataRecord.ValueInformationBlock

  doctest Exmbus.Apl.DataRecord, import: true

  describe "Main VIFE-code extension table (0xFD)" do
    test "0bE0010111 Error flags" do
      {:ok, record, <<0xFF, 0xFF>>} = DataRecord.decode(<<0x02, 0xfd, 0x17, 0x00, 0x00, 0xFF, 0xFF>>)

      assert %DataRecord{
        data: 0,
        header: %Header{
          dib: %DataInformationBlock{
            coding: :int,
            device: 0,
            function_field: :instantaneous,
            size: 16,
            storage: 0,
            tariff: 0
          },
          vib: %ValueInformationBlock{
            description: :error_flags,
            extensions: [],
            multiplier: nil,
            override_data_type: nil,
            unit: ""
          }
        }
      } = record
    end
  end
end
