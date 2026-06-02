defmodule Parser.Apl.DataRecord.UnhandledVifeTest do
  use ExUnit.Case, async: true

  test "Even if we haven't implemented a specific VIFE, it should not crash the parser" do
    assert {:ok, ctx} =
             [
               bin: Base.decode16!("0DFD8E80FC0107302E34322E3142"),
               handlers: [&Exmbus.Parser.Apl.parse/1]
             ]
             |> Exmbus.Parser.Context.new()
             |> Exmbus.Parser.parse()

    assert [firmware_version_record] = ctx.apl.records
    assert length(firmware_version_record.header.vib.extensions) == 2
  end
end
