defmodule KeyTest do
  use ExUnit.Case, async: true
  alias Exmbus.Parser.Context
  alias Exmbus.Key

  doctest Exmbus.Key, import: true

  test "by_fn!" do
    f = fn _ -> :dummy end
    assert %Key{keyfn: ^f} = Key.by_fn!(f)
    # assert arity check works
    assert_raise FunctionClauseError, fn ->
      Key.by_fn!(fn -> :bad end)
    end

    assert_raise FunctionClauseError, fn ->
      Key.by_fn!(fn _, _ -> :bad end)
    end
  end

  test "from_options!" do
    # assert from_options! given a Key struct as :key will return as is
    key = %Key{keyfn: :dummy}
    assert ^key = Key.from_options!(%{key: key})

    # assert given a single binary will return a Key with a fn always returning that key
    key = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
    assert {:ok, [^key]} = Key.from_options!(%{key: key}).keyfn.(Context.new())
    # assert given a single non-binary will raise FunctionClauseError
    assert_raise FunctionClauseError, fn -> Key.from_options!(%{key: 1}).keyfn.(Context.new()) end

    # assert given a list of binary keys will return that list
    assert {:ok, [^key, ^key]} = Key.from_options!(%{key: [key, key]}).keyfn.(Context.new())
    # assert given an empty list returns an empty list
    assert {:ok, []} = Key.from_options!(%{key: []}).keyfn.(Context.new())
    # assert given a list of non-binary keys will FunctionClauseError
    assert_raise FunctionClauseError, fn ->
      Key.from_options!(%{key: [1, 2]}).keyfn.(Context.new())
    end

    # assert given an option map with no :key key, will raise
    assert_raise RuntimeError, fn -> Key.from_options!(%{}) end
  end
end
