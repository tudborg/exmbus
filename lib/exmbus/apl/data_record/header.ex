
defmodule Exmbus.Apl.DataRecord.Header do
  alias Exmbus.Apl.DataRecord.DataInformationBlock, as: DIB
  alias Exmbus.Apl.DataRecord.ValueInformationBlock, as: VIB

  use Bitwise

  # The header struct
  defstruct [
    dib: nil,
    vib: nil,
  ]

  @doc """
  Decodes the next DataRecord header from a binary.

    iex> decode(<<0b00000001, 0b00000011, 0xFF>>)
    {:ok, %Header{
      dib: %DataInformationBlock{coding: :int, device: 0, function_field: :instantaneous, size: 8, storage: 0, tariff: 0},
      vib: %ValueInformationBlock{description: :energy, extensions: [], multiplier: 1, unit: "Wh"}
    }, <<0xFF>>}

    iex> decode(<<0x0F, 0x2F, 0xFF>>)
    {:special_function, {:manufacturer_specific, :to_end}, <<0x2F, 0xFF>>}

    iex> decode(<<0x2F, 0x2F, 0xFF>>)
    {:special_function, :idle_filler, <<0x2F, 0xFF>>}
  """
  @spec decode(binary())
    :: {:ok, header :: %__MODULE__{}, rest :: binary()}
    |  DIB.special_function()
  def decode(bin) do
    case DIB.decode(bin) do
      {:ok, dib, rest} ->
        # we found a DataInformationBlock, continue to parse header.
        {:ok, vib, rest} = VIB.decode(rest)
        {:ok, %__MODULE__{dib: dib, vib: vib}, rest}
      {:special_function, _type, _rest}=s ->
        s # we just return the special function. The parser upstream will have to decide what to do,
          # but there isn't a real header here. The APL layer knows what to do.
    end
  end

end
