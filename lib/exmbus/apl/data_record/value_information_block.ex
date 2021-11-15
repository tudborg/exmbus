defmodule Exmbus.Apl.DataRecord.ValueInformationBlock do
  @moduledoc """
  The Value Information Block utilities
  """

  alias Exmbus.Apl.DataRecord.DataInformationBlock, as: DIB
  alias Exmbus.Apl.DataRecord.ValueInformationBlock.VifTableMain

  defstruct [
    # VIB fields:
    description: nil, # An atom describing the value. This is an atomized version of the "Description" from the documentation.
    multiplier: nil,  # A multiplier to apply to the data. It's part of the VIF(E) information.
    unit: nil,        # A string giving the unit of the value (e.g. kJ/h or °C)
    extensions: [],   # A list of extensions that might modify the meaning of the data.

    # Implied by a combination of the above
    coding: nil,       # If set, decode according to this datatype instead of what is found in the DIB
    #                  # Options are: type_a, type_b, type_c, type_d, type_f, type_g,
    #                  #              type_h, type_i, type_j, type_k, type_l, type_m
  ]

  def parse(bin, opts, [%DIB{} | _]=ctx) do
    # delegate the parsing to the primary table
    VifTableMain.parse(bin, opts, ctx)
  end

end
