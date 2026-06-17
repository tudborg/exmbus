defmodule Exmbus.Parser.Dll do
  @moduledoc """
  Routes the parsing to the correct Dll parser,
  either Mbus or Wmbus.
  """
  alias Exmbus.Parser.Context
  alias Exmbus.Parser.Dll.Mbus
  alias Exmbus.Parser.Dll.Wmbus

  @spec parse(ctx :: Context.t()) :: {:next, Context.t()} | {:halt, Context.t()}
  def parse(%{bin: <<0x68, len, len, 0x68, _::binary>>} = ctx) do
    # mbus with length
    Mbus.parse(ctx)
  end

  def parse(ctx) do
    # probably wmbus if not mbus
    Wmbus.parse(ctx)
  end

  def unparse(%{dll: nil} = ctx) do
    {:next, ctx}
  end

  def unparse(%{dll: %Mbus{}} = ctx) do
    Mbus.unparse(ctx)
  end

  def unparse(%{dll: %Wmbus{}} = ctx) do
    Wmbus.unparse(ctx)
  end
end
