defmodule Exmbus.Parser.Identity do
  @moduledoc """
  Identity of a device (meter, gateway, partner, etc)
  """
  alias Exmbus.Parser.IdentificationNo
  alias Exmbus.Parser.Tpl.Device
  alias Exmbus.Parser.Manufacturer

  defstruct identification_no: nil,
            manufacturer: nil,
            version: nil,
            device: nil

  @type t :: %__MODULE__{
          identification_no: String.t(),
          manufacturer: String.t(),
          version: integer(),
          device: Exmbus.Parser.Tpl.Device.t()
        }

  def decode(<<man_b::binary-size(2), id_b::binary-size(4), v, d_b::binary-size(1)>>) do
    with {:ok, identification_no} <- IdentificationNo.decode(id_b),
         {:ok, device} <- Device.decode(d_b),
         {:ok, manufacturer} <- Manufacturer.decode(man_b) do
      {:ok,
       %__MODULE__{
         identification_no: identification_no,
         manufacturer: manufacturer,
         version: v,
         device: device
       }}
    end
  end
end
