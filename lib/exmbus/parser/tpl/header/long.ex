defmodule Exmbus.Parser.Tpl.Header.Long do
  @moduledoc """
  This module represents the Long header in the TPL layer.
  """

  @type t :: %__MODULE__{
          identification_no: String.t(),
          manufacturer: String.t(),
          version: integer(),
          device: Exmbus.Parser.Tpl.Device.t(),
          access_no: integer(),
          status: Exmbus.Parser.Tpl.Status.t(),
          configuration_field: Exmbus.Parser.Tpl.ConfigurationField.t()
        }

  defstruct identification_no: nil,
            manufacturer: nil,
            version: nil,
            device: nil,
            access_no: nil,
            status: nil,
            configuration_field: nil
end
