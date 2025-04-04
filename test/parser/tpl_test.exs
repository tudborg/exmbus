defmodule Parser.TplTest do
  use ExUnit.Case, async: true
  doctest Exmbus.Parser.Tpl, import: true
  doctest Exmbus.Parser.Tpl.Device, import: true
  doctest Exmbus.Parser.Tpl.ConfigurationField, import: true
end
