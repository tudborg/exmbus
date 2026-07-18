defmodule ExmbusTest do
  use ExUnit.Case, async: true

  alias Exmbus.Parser.Context
  alias Exmbus.Parser.ParseError

  @frame Base.decode16!(
           "2E4493157856341233037A2A0000002F2F0C1427048502046D32371F1502FD1700002F2F2F2F2F2F2F2F2F2F2F2F2F"
         )

  doctest Exmbus

  describe "parse/2" do
    test "parses with the default options" do
      assert {:ok, %Context{bin: <<>>, errors: []}} = Exmbus.parse(@frame)
    end

    test "accepts options as a keyword list or map" do
      assert {:ok, %Context{bin: <<>>}} = Exmbus.parse(@frame, length: true)

      assert {:ok, %Context{bin: <<>>}} = Exmbus.parse(@frame, %{length: true})
    end

    test "reuses a context while replacing its input" do
      context = Context.new(bin: "old", handlers: [], opts: [crc: true])

      assert {:ok, %Context{bin: "new", opts: %{crc: true}}} =
               Exmbus.parse("new", context)
    end
  end

  describe "parse!/2" do
    test "returns the context after a successful parse" do
      context = Context.new(handlers: [])

      assert %Context{bin: "payload"} = Exmbus.parse!("payload", context)
    end

    test "raises a parse error containing the accumulated errors" do
      context = Context.new(handlers: [], errors: [{nil, :invalid_frame}])

      assert_raise ParseError,
                   "Failed to parse data. reasons=[nil: :invalid_frame]",
                   fn -> Exmbus.parse!(<<>>, context) end
    end
  end

  test "crc!/1 calculates the EN 13757 check value" do
    assert Exmbus.crc!("123456789") == 0xC2B7
  end
end
