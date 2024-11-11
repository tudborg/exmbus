defmodule Exmbus.Parser.Dll do
  @behaviour Exmbus.Parser.ParseBehaviour
  @moduledoc """
  Routes the parsing to the correct Dll parser,
  either Mbus or Wmbus.
  """

  @spec parse(ctx :: Exmbus.Parser.Context.t()) ::
          {:continue, Context.t()} | {:abort, Context.t()}
  def parse(%{rest: <<0x68, len, len, 0x68, _::binary>>} = ctx) do
    # mbus with length
    Exmbus.Parser.Dll.Mbus.parse(ctx)
  end

  def parse(ctx) do
    # probably wmbus if not mbus
    Exmbus.Parser.Dll.Wmbus.parse(ctx)
  end
end
