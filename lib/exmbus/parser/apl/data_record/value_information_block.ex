defmodule Exmbus.Parser.Apl.DataRecord.ValueInformationBlock do
  @moduledoc """
  The Value Information Block utilities
  """
  alias __MODULE__, as: VIB
  alias Exmbus.Parser.Apl.DataRecord.ValueInformationBlock.VifTableMain
  alias Exmbus.Parser.Context

  @type t :: %__MODULE__{
          description: atom(),
          multiplier: nil | integer(),
          unit: nil | binary(),
          extensions: [any],
          coding:
            nil
            | :type_a
            | :type_b
            | :type_c
            | :type_d
            | :type_f
            | :type_g
            | :type_h
            | :type_i
            | :type_j
            | :type_k
            | :type_l
            | :type_m,
          table: atom()
        }

  defstruct [
    # VIB fields:
    # An atom describing the value. This is an atomized version of the "Description" from the documentation.
    description: nil,
    # A multiplier to apply to the data. It's part of the VIF(E) information.
    multiplier: nil,
    # A string giving the unit of the value (e.g. kJ/h or °C)
    unit: nil,
    # A list of extensions that might modify the meaning of the data.
    extensions: [],

    # Implied by a combination of the above
    # If set, decode according to this datatype instead of what is found in the DIB
    coding: nil,
    #                  # Options are: type_a, type_b, type_c, type_d, type_f, type_g,
    #                  #              type_h, type_i, type_j, type_k, type_l, type_m

    # the table used to find the primary VIF.
    # This _could_ probably be inferred by the above description and multiplier
    # but it is really convenient to pattern match against in the Vife module.
    # Maybe we'll refactor it out in the future.
    table: nil
  ]

  @spec parse(binary, Context.t()) ::
          {:ok, VIB.t(), rest :: binary} | {:error, any, binary}
  def parse(bin, ctx) do
    # delegate the parsing to the primary table
    VifTableMain.parse(bin, ctx)
  end

  # Basic unparse, main table, no extensions
  def unparse(%VIB{table: :main} = vib) do
    VifTableMain.unparse(vib)
  end
end
