defmodule DataRecordTest do
  use ExUnit.Case

  alias Exmbus.Apl.DataRecord
  alias Exmbus.Apl.DataRecord.Header
  alias Exmbus.Apl.DataRecord.DataInformationBlock
  alias Exmbus.Apl.DataRecord.ValueInformationBlock

  doctest Exmbus.Apl.DataRecord, import: true

  describe "Main VIFE-code extension table (0xFD)" do
    test "0bE0010111 Error flags" do
      {:ok, record, <<0xFF, 0xFF>>} = DataRecord.decode(<<0x02, 0xfd, 0x17, 0b00000100, 0b10000000, 0xFF, 0xFF>>)

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
end
