defmodule ExmbusTest do
  use ExUnit.Case
  doctest Exmbus

  test "greets the world" do
    assert Exmbus.hello() == :world
  end
end
