defmodule DataRecordHeaderTest do
  use ExUnit.Case

  alias Exmbus.Apl.DataRecord.Header
  alias Exmbus.Apl.DataRecord.DataInformationBlock
  alias Exmbus.Apl.DataRecord.ValueInformationBlock

  doctest Exmbus.Apl.DataRecord.Header, import: true
  doctest Exmbus.Apl.DataRecord.DataInformationBlock, import: true
  doctest Exmbus.Apl.DataRecord.ValueInformationBlock, import: true

end
