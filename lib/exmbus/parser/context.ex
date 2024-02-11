defmodule Exmbus.Parser.Context do
  @moduledoc """
  Parsing context, accumulating errors and layers.
  """

  @type t :: %__MODULE__{
          dll: any,
          tpl: any,
          ell: any,
          apl: any,
          #
          dib: any,
          vib: any,
          #
          errors: [any]
        }

  defstruct [
    # lower layers:
    dll: nil,
    ell: nil,
    tpl: nil,
    apl: nil,
    # state for when parsing data record:
    dib: nil,
    vib: nil,
    # error accumulator
    errors: []
  ]

  def layer(ctx, layer, data), do: %{ctx | layer => data}

  def new(attrs \\ []) do
    Enum.reduce(attrs, %__MODULE__{}, &Map.put(&2, elem(&1, 0), elem(&1, 1)))
  end

  @doc """
  Add an error to the context and return the updated context.
  """
  def add_error(ctx, error) do
    %{ctx | errors: [error | ctx.errors]}
  end
end
