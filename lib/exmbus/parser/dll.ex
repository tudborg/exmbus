defmodule Exmbus.Parser.Dll do
  @moduledoc """
  Routes the parsing to the correct Dll parser,
  either Mbus or Wmbus.
  """
  alias Exmbus.Parser.Context

  @spec parse(ctx :: Context.t()) :: {:next, Context.t()} | {:halt, Context.t()}
  def parse(%{bin: <<0x68, len, len, 0x68, _::binary>>} = ctx) do
    # mbus with length
    Exmbus.Parser.Dll.Mbus.parse(ctx)
  end

  def parse(ctx) do
    # probably wmbus if not mbus
    Exmbus.Parser.Dll.Wmbus.parse(ctx)
  end
end
