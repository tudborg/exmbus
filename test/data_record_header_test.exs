defmodule DataRecordHeaderTest do
  use ExUnit.Case

  alias Exmbus.Apl.DataRecord.DataInformationBlock, as: DIB
  alias Exmbus.Apl.DataRecord.ValueInformationBlock, as: VIB

  doctest Exmbus.Apl.DataRecord.Header, import: true
  doctest Exmbus.Apl.DataRecord.DataInformationBlock, import: true
  doctest Exmbus.Apl.DataRecord.ValueInformationBlock, import: true


  describe "DataInformationBlock" do

    for i <- 0x00..0x0E do
      test "parse/unparse #{i}" do
        bin = <<unquote(i)>>
        assert {:ok, %DIB{}=dib, <<>>} = DIB.parse(bin, %{}, [])
        assert {:ok, ^bin} = DIB.unparse(%{}, [dib])
      end
    end


  end
end
