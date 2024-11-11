defmodule Exmbus.Parser.ParseBehaviour do
  @doc """
  Parse a context using it's `bin` binary as data.
  Returns a tuple with the new context.

  The tuple is either a `continue`, `done` or `error` tuple.

  - `continue` The caller should continue parsing the context against the next layer.
  - `abort` The caller should abort the parsing.
  """
  @callback parse(Context.t()) :: {:continue, Context.t()} | {:abort, Context.t()}
end
