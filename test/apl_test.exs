defmodule AplTest do
  use ExUnit.Case

  alias Exmbus.Apl
  alias Exmbus.Apl.DataRecord
  alias Exmbus.Apl.DataRecord.Header
  alias Exmbus.Apl.DataRecord.DataInformationBlock
  alias Exmbus.Apl.DataRecord.ValueInformationBlock

  doctest Exmbus.Apl, import: true

end
