defmodule Exmbus.Parser do
  @behaviour Exmbus.Parser.ParseBehaviour
  @moduledoc """
  Responsible for parsing the binary data into a structured format.
  """
  alias Exmbus.Parser.Context

  @doc """
  Parse the parse context until it's handler stack is empty, or it has errors.
  """
  @spec parse(Context.t()) :: Context.t()
  def parse(%Context{handlers: []} = ctx) do
    {:continue, ctx}
  end

  def parse(%Context{errors: [_ | _]} = ctx) do
    {:abort, ctx}
  end

  def parse(%Context{handlers: [next | remaining]} = ctx) do
    # recursively parse the context while parse/1 returns {:continue, ctx}
    with {:continue, ctx} <- next.(%{ctx | handlers: remaining}) do
      parse(ctx)
    end
  end
end
