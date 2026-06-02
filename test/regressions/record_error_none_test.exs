defmodule Regressions.RecordErrorNoneTest do
  @moduledoc """
  This test came about due to a real world record from an ABB meter that used a
  VIFE for record_error=none, but not as the first VIFE. The old way of parsing this
  special-case was handled in such a way that only the first extension location would allow this.
  """
  use ExUnit.Case, async: true

  test "Record error none VIFE should be handled correctly" do
    assert {:ok, ctx} =
             [
               bin: Base.decode16!("0DFD8E0007302E34322E3142"),
               handlers: [&Exmbus.Parser.Apl.parse/1]
             ]
             |> Exmbus.Parser.Context.new()
             |> Exmbus.Parser.parse()

    assert [firmware_version_record] = ctx.apl.records
    assert firmware_version_record.header.vib.description == :firmware_version_number
    assert firmware_version_record.header.vib.extensions == [{:record_error, :none}]
    # the record also contained this value, but it isn't relevant to this specific test:
    assert firmware_version_record.data == "0.42.1B"
  end
end
