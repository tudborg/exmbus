defmodule Exmbus.Parser.Identity do
  @moduledoc """
  Identity of a device (meter, gateway, partner, etc)
  """
  alias Exmbus.Parser.IdentificationNo
  alias Exmbus.Parser.Manufacturer
  alias Exmbus.Parser.Tpl.Device

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

  def encode(%__MODULE__{identification_no: id, manufacturer: man, version: v, device: d}) do
    with {:ok, man_b} <- Manufacturer.encode(man),
         {:ok, id_b} <- IdentificationNo.encode(id),
         {:ok, d_b} <- Device.encode(d) do
      {:ok, <<man_b::binary-size(2), id_b::binary-size(4), v, d_b::binary-size(1)>>}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end
end
