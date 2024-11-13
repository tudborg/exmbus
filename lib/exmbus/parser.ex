defmodule Exmbus.Parser do
  @moduledoc """
  Responsible for parsing the binary data into a structured format.
  """
  alias Exmbus.Parser.Context

  @doc """
  Parse the parse context until it's handler stack is empty, or it has errors.

  Returns {:ok, ctx} if parsing was successful, or {:error, ctx} if parsing failed.
  """
  @spec parse(Context.t()) :: {:ok, Context.t()} | {:error, Context.t()}
  def parse(ctx), do: handle(ctx)

  defp handle(%Context{handlers: []} = ctx), do: reply(ctx)

  defp handle(%Context{handlers: [_ | _]} = ctx) do
    case Context.handle(ctx) do
      {:next, ctx} -> handle(ctx)
      {:halt, ctx} -> reply(ctx)
    end
  end

  defp reply(%Context{errors: [_ | _]} = ctx), do: {:error, ctx}
  defp reply(%Context{errors: []} = ctx), do: {:ok, ctx}
end
