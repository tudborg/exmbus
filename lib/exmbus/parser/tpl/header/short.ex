defmodule Exmbus.Parser.Tpl.Header.Short do
  @moduledoc """
  This module represents the short header of the TPL layer.
  """

  @type t :: %__MODULE__{
          access_no: integer(),
          status: Exmbus.Parser.Tpl.Status.t(),
          configuration_field: Exmbus.Parser.Tpl.ConfigurationField.t()
        }

  defstruct access_no: nil,
            status: nil,
            configuration_field: nil
end
