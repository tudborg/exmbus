defmodule Parser.AflTest do
  use ExUnit.Case, async: true

  doctest Exmbus.Parser.Afl.FragmentationControlField, import: true
  doctest Exmbus.Parser.Afl.MessageControlField, import: true
  doctest Exmbus.Parser.Afl.KeyInformationField, import: true
end
