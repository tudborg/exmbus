defmodule Parser.TableLoaderTest do
  use ExUnit.Case, async: true

  alias Exmbus.Parser.TableLoader

  test "from_file!/1" do
    path = Application.app_dir(:exmbus, "priv/ci.csv")
    assert [_ | _] = TableLoader.from_file!(path)
    path = Application.app_dir(:exmbus, "priv/device.csv")
    assert [_ | _] = TableLoader.from_file!(path)
  end

  test "from_enumerable!/1" do
    enumerable = [
      "hex;int;float;str;atom;:atom;range",
      # explicit prefixes:
      "hex:0x01;int:1;float:1.0;str:1;atom:one;:one;1..1",
      "hex:0x02;int:2;float:2.0;str:2;atom:two;:two;2..2",
      # implicit detection:
      "0x03;3;3.0;str:3;:three;:three;3..3"
    ]

    assert [
             {<<0x01>>, 1, 1.0, "1", :one, :one, {:range, 1, 1}},
             {<<0x02>>, 2, 2.0, "2", :two, :two, {:range, 2, 2}},
             {<<0x03>>, 3, 3.0, "3", :three, :three, {:range, 3, 3}}
           ] = TableLoader.from_enumerable!(enumerable)
  end

  test "from_enumerable!/1 errors" do
    assert_raise ArgumentError, fn ->
      TableLoader.from_enumerable!(["hex", "hex:0xGG"])
    end

    assert_raise RuntimeError, fn ->
      TableLoader.from_enumerable!(["int", "int:abc"])
    end

    assert_raise RuntimeError, fn ->
      TableLoader.from_enumerable!(["int", "int:12threefour"])
    end

    assert_raise RuntimeError, fn ->
      TableLoader.from_enumerable!(["float", "float:abc"])
    end

    assert_raise RuntimeError, fn ->
      TableLoader.from_enumerable!(["float", "float:1.0threefour"])
    end
  end
end
