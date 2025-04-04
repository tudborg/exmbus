defmodule Exmbus.Parser.Tpl.Header.Short do
  @type t :: %__MODULE__{
          access_no: integer(),
          status: Exmbus.Parser.Tpl.Status.t(),
          configuration_field: Exmbus.Parser.Tpl.ConfigurationField.t()
        }

  defstruct access_no: nil,
            status: nil,
            configuration_field: nil
end
