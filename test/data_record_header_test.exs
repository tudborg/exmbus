defmodule DataRecordHeaderTest do
  use ExUnit.Case, async: true

  alias Exmbus.Apl.DataRecord.Header
  alias Exmbus.Apl.DataRecord.DataInformationBlock, as: DIB
  alias Exmbus.Apl.DataRecord.ValueInformationBlock, as: VIB

  doctest Exmbus.Apl.DataRecord.Header, import: true

  describe "regressions" do
    test "parse/unparse header mismatch 2022-01-14" do
      # unparsing this yielded 01FA21 which ofc is wrong, it should be same as input
      orignal_drh = "01FF21" |> Base.decode16!()
      {:ok, [%Header{} = header], ""} = Header.parse(orignal_drh, %{}, [])

      assert %Exmbus.Apl.DataRecord.Header{
               coding: :type_b,
               dib: %DIB{
                 data_type: :int_or_bin,
                 device: 0,
                 function_field: :instantaneous,
                 size: 8,
                 storage: 0,
                 tariff: 0
               },
               dib_bytes: <<1>>,
               vib: %VIB{
                 coding: nil,
                 description: :manufacturer_specific_encoding,
                 extensions: [manufacturer_specific_vife: 33],
                 multiplier: nil,
                 table: :main,
                 unit: nil
               },
               vib_bytes: <<255, 33>>
             } = header
      header = Map.drop(header, [:dib_bytes, :vib_bytes]) # be sure we don't "cheat" :)
      assert {:ok, <<0x01, 0xFF, 0x21>>, []} = Header.unparse(%{}, [header])
    end
  end
end
