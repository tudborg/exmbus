defmodule Parser.BinaryTest do
  use ExUnit.Case, async: true
  alias Exmbus.Parser.Binary
  doctest Exmbus.Parser.Binary, import: true

  test "test collect_by_extension_bit optimization (up to 4 collected bytes)" do
    # this triggers an optimization
    assert {:ok, <<0x80, 0x80, 0x00>>, <<0x00>>} =
             Binary.collect_by_extension_bit(<<1::1, 0::7, 1::1, 0::7, 0x00, 0x00>>)
  end

  test "test generic_collect_by_extension_bit (more than 4 collected bytes)" do
    # this private function is hidden behind the public function that optimizes
    # the common case. So to trigger this, we need to have more than 4 captured bytes.

    capture = <<0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x00>>
    tail = <<0x00, 0x80, 0x00, 0x80, 0x00, 0x80, 0x00>>

    assert {:ok, ^capture, ^tail} =
             Binary.collect_by_extension_bit(<<capture::binary, tail::binary>>)
  end
end
