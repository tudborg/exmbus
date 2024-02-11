defmodule Exmbus.Parser.Context do
  @moduledoc """
  Parsing context, accumulating errors and layers.
  """

  defstruct [
    # layers
    dll: nil,
    tpl: nil,
    ell: nil,
    apl: nil,
    # error accumulator
    errors: []
  ]

  def new() do
    %__MODULE__{}
  end

  @doc """
  Add an error to the context and return the updated context.
  """
  def add_error(ctx, error) do
    %{ctx | errors: [error | ctx.errors]}
  end
end
