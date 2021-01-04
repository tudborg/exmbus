defmodule Exmbus.Apl.DataRecord.DataInformationBlock do
  use Bitwise

  @moduledoc """
  The Data Information Block.
  Contains the DIF+DIFE
  """
  defstruct [
    device: nil,
    tariff: nil,
    storage: nil,
    function_field: nil,
    # the coding and size comes from decoding the Data Field in the DIB
    # they are split for easier access
    coding: nil,
    size: nil,
  ]

  @doc """
  Decode DIB (Data Information Block) and return a %DataInformationBlock{} struct

    iex> decode(<<0x0F, 0xFF>>)
    {:special_function, {:manufacturer_specific, :to_end}, <<0xFF>>}

    iex> decode(<<0x1F, 0xFF>>)
    {:special_function, {:manufacturer_specific, :more_records_follow}, <<0xFF>>}

    iex> decode(<<0x2F, 0xFF>>)
    {:special_function, :idle_filler, <<0xFF>>}

    iex> decode(<<0x3F, 0xFF>>)
    ** (RuntimeError) special function DIF 0x3F reserved for future use

    iex> decode(<<0x6F, 0xFF>>)
    ** (RuntimeError) special function DIF 0x6F reserved for future use

    iex> decode(<<0x7F, 0xFF>>)
    {:special_function, :global_readout_request, <<0xFF>>}

    iex> decode(<<0b00000000, 0xFF>>)
    {:ok, %DataInformationBlock{
      device: 0,
      tariff: 0,
      storage: 0,
      function_field: :instantaneous,
      coding: :no_data,
      size: 0
    }, <<0xFF>>}

    iex> decode(<<0b01010001, 0xFF>>)
    {:ok, %DataInformationBlock{
      device: 0,
      tariff: 0,
      storage: 1,
      function_field: :maximum,
      coding: :int,
      size: 8,
    }, <<0xFF>>}

    iex> decode(<<0b10000111, 0b01010001, 0xFF>>)
    {:ok, %DataInformationBlock{
      device: 1,
      tariff: 1,
      storage: 2,
      function_field: :instantaneous,
      coding: :int,
      size: 64,
    }, <<0xFF>>}

    iex> decode(<<0b10000111, 0b11010001, 0b00000001, 0xFF>>)
    {:ok, %DataInformationBlock{
      device: 1,
      tariff: 1,
      storage: 34,
      function_field: :instantaneous,
      coding: :int,
      size: 64,
    }, <<0xFF>>}

  """
  # match special functions headers.
  # Special function DIBs is not followed by VIBs and data and so are not really record headers.
  # their return values are special (i.e. Not a __MODULE__ struct)
  @type special_function_type()
    :: {:manufacturer_specific, :to_end}
    |  {:manufacturer_specific, :more_records_follow}
    |  :idle_filler
    |  :global_readout_request
  @type special_function() :: {:special_function, special_function_type(), rest :: binary()}
  @spec decode(binary()) :: {:ok, %__MODULE__{}, rest :: binary()} | special_function()
  def decode(<<special::4, 0b1111::4, rest::binary>>) do
    # note that we are effectively stripping the least-significant bits of the dif which is
    # always 0b1111 (i.e. 0xF) for special functions, so the following case only checks for the top
    # 4 bits. In the manual these are written together (i.e. 0x0F), here we only write the MSB (0x0 instead of 0x0F)
    case special do
      # Start of manufacturer specific data structures to end of user data(see 6.5)
      0x0 -> {:special_function, {:manufacturer_specific, :to_end}, rest}
      # Same meaning as DIF = 0Fh + more records follow in next datagram (see 6.5)
      0x1 -> {:special_function, {:manufacturer_specific, :more_records_follow}, rest}
      # Idle filler, following byte is DIF, we could just recurse directly but let's keep the structure and return a special
      0x2 -> {:special_function, :idle_filler, rest}
      # special function range reserved for future use
      r when r >= 0x3 and r <= 0x6 -> raise "special function DIF 0x#{Integer.to_string((r <<< 4) ||| 0xF, 16)} reserved for future use"
      # Global readout request (all storage numbers, units, tariffs, function fields)
      # TODO what does this mean exactly?
      0x7 -> {:special_function, :global_readout_request, rest}
    end
  end
  # regular DIF parsing:
  def decode(<<1::1, lsb_storage::1, ff::2, df::4, rest::binary>>) do
    # extension bit set, LSBit of storage number, function field, data field:
    # we grab the extended device,tariff,storage
    # NOTE: the DIF contained the lowest bit of storage, so we need to shift storage up
    # and bitwise or it with the lsb_storage bit
    {:ok, device, tariff, msb_storage, rest} = decode_header_dife(rest)
    {coding, size} = decode_data_field(df)
    {:ok, %__MODULE__{
      device: device,
      tariff: tariff,
      storage: (msb_storage <<< 1) ||| lsb_storage,
      function_field: decode_function_field(ff),
      coding: coding,
      size: size,
    }, rest}
  end
  def decode(<<0::1, storage::1, ff::2, df::4, rest::binary>>) do
    {coding, size} = decode_data_field(df)
    {:ok, %__MODULE__{
      device: 0,
      tariff: 0,
      storage: storage,
      function_field: decode_function_field(ff),
      coding: coding,
      size: size,
    }, rest}
  end

  # decodes series of DIFE bytes.
  # Note that this function should only be called if the DIF had the extension bit set.
  defp decode_header_dife(<<0::1, device::1, tariff::2, storage::4, rest::binary>>) do
    {:ok, device, tariff, storage, rest}
  end
  defp decode_header_dife(<<1::1, l_device::1, l_tariff::2, l_storage::4, rest::binary>>) do
    {:ok, m_device, m_tariff, m_storage, rest} = decode_header_dife(rest)
    {:ok,
      (m_device <<< 1) ||| l_device,
      (m_tariff <<< 2) ||| l_tariff,
      (m_storage <<< 4) ||| l_storage,
      rest
    }
  end

  # data field conversion to nicer internal format.
  defp decode_data_field(0b0000), do: {:no_data, 0}
  defp decode_data_field(0b0001), do: {:int, 8}
  defp decode_data_field(0b0010), do: {:int, 16}
  defp decode_data_field(0b0011), do: {:int, 24}
  defp decode_data_field(0b0100), do: {:int, 32}
  defp decode_data_field(0b0101), do: {:real, 32}
  defp decode_data_field(0b0110), do: {:int, 48}
  defp decode_data_field(0b0111), do: {:int, 64}
  defp decode_data_field(0b1000), do: {:selection_for_readout, 0}
  defp decode_data_field(0b1001), do: {:bcd, 8} # 2 digit BCD
  defp decode_data_field(0b1010), do: {:bcd, 16} # 4 digit BCD
  defp decode_data_field(0b1011), do: {:bcd, 24} # 6 digit BCD
  defp decode_data_field(0b1100), do: {:bcd, 32} # 8 digit BCD
  defp decode_data_field(0b1101), do: {:variable_length, :lvar}
  defp decode_data_field(0b1110), do: {:bcd, 48} # 12 digit BCD
  defp decode_data_field(0b1111), do: raise "unexpected special function coding, this should have been handled already"

  # function field to atom
  defp decode_function_field(0b00), do: :instantaneous
  defp decode_function_field(0b01), do: :maximum
  defp decode_function_field(0b10), do: :minimum
  defp decode_function_field(0b11), do: :value_during_error_state

end
