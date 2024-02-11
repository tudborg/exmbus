defmodule Exmbus.Parser.Dll do
  @moduledoc """
  Routes the parsing to the correct Dll parser,
  either Mbus or Wmbus.
  """

  @spec parse(binary, map, Exmbus.Parser.Context.t()) ::
          {:ok, any, binary} | {:error, any, Exmbus.Parser.Context.t()}
  def parse(<<0x68, len, len, 0x68, _::binary>> = bin, opts, ctx) do
    # mbus with length
    Exmbus.Parser.Dll.Mbus.parse(bin, opts, ctx)
  end

  def parse(bin, opts, ctx) do
    # probably wmbus if not mbus
    Exmbus.Parser.Dll.Wmbus.parse(bin, opts, ctx)
  end
end
