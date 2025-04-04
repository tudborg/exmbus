defmodule Exmbus.Parser.Apl.DataRecord.DataInformationBlock do
  import Bitwise

  @type function_field :: :instantaneous | :maximum | :minimum | :value_during_error_state
  @type data_type ::
          :no_data | :int_or_bin | :real | :bcd | :variable_length | :selection_for_readout

  @type t :: %__MODULE__{
          device: integer(),
          tariff: integer(),
          storage: integer(),
          function_field: function_field(),
          data_type: atom(),
          size: integer() | :variable_length
        }

  defstruct [
    # DIB fields:
    # device is what is also called "subunit"
    device: nil,
    tariff: nil,
    storage: nil,
    function_field: nil,
    # the coding and size comes from decoding the Data Field in the DIB
    # they are split for easier access
    # the data_type is integer/binary, real, bcd, variable_length and so on
    data_type: nil,
    # the size of the value in bits, or :variable_length
    size: nil
  ]

  def unparse(_opts, %__MODULE__{device: 0, tariff: 0, storage: s} = dib) when s <= 1 do
    ff_int = encode_function_field(dib.function_field)
    df_int = encode_data_field(dib.data_type, dib.size)
    {:ok, <<0::1, s::1, ff_int::2, df_int::4>>}
  end

  def parse(<<special::4, 0b1111::4, rest::binary>>, _opts, _ctx) do
    # note that we are effectively stripping the least-significant bits of the dif which is
    # always 0b1111 (i.e. 0xF) for special functions, so the following case only checks for the top
    # 4 bits. In the manual these are written together (i.e. 0x0F), here we only write the MSB (0x0 instead of 0x0F)
    case special do
      # Start of manufacturer specific data structures to end of user data(see 6.5)
      0x0 ->
        {:special_function, {:manufacturer_specific, :to_end}, rest}

      # Same meaning as DIF = 0Fh + more records follow in next datagram (see 6.5)
      # This is a "request" from the meter to the station, to request more data.
      0x1 ->
        {:special_function, {:manufacturer_specific, :more_records_follow}, rest}

      # Idle filler, following byte is DIF, we could just recurse directly but let's keep the structure and return a special
      0x2 ->
        {:special_function, :idle_filler, rest}

      # special function range reserved for future use
      r when r >= 0x3 and r <= 0x6 ->
        {:error, {:reserved_special_function, r <<< 4 ||| 0xF}, rest}

      # Global readout request (all storage numbers, units, tariffs, function fields)
      # TODO what does this mean exactly?
      0x7 ->
        {:special_function, :global_readout_request, rest}
    end
  end

  # regular DIF parsing:
  def parse(<<e::1, lsb_storage::1, ff::2, df::4, rest::binary>>, _opts, _ctx) do
    {:ok, device, tariff, msb_storage, rest} =
      case e do
        # if extensions, decode dife:
        1 -> parse_header_dife(rest)
        # else return defaults:
        0 -> {:ok, 0, 0, 0, rest}
      end

    #
    storage = msb_storage <<< 1 ||| lsb_storage
    {data_type, size} = decode_data_field(df)

    {:ok,
     %__MODULE__{
       device: device,
       tariff: tariff,
       storage: storage,
       function_field: decode_function_field(ff),
       data_type: data_type,
       size: size
     }, rest}
  end

  # decodes series of DIFE bytes.
  # Note that this function should only be called if the DIF had the extension bit set.
  defp parse_header_dife(<<0::1, device::1, tariff::2, storage::4, rest::binary>>) do
    {:ok, device, tariff, storage, rest}
  end

  defp parse_header_dife(<<1::1, l_device::1, l_tariff::2, l_storage::4, rest::binary>>) do
    {:ok, m_device, m_tariff, m_storage, rest} = parse_header_dife(rest)

    {:ok, m_device <<< 1 ||| l_device, m_tariff <<< 2 ||| l_tariff, m_storage <<< 4 ||| l_storage,
     rest}
  end

  @moduledoc """
  Utilities for DIB parsing
  """

  def default_coding(%__MODULE__{data_type: data_type}), do: default_coding(data_type)
  def default_coding(:int_or_bin), do: :type_b
  def default_coding(:real), do: :type_h
  def default_coding(:bcd), do: :type_a
  def default_coding(_), do: nil

  # data field conversion to nicer internal format.
  # returns data_type, size in bits
  def decode_data_field(0b0000), do: {:no_data, 0}
  def decode_data_field(0b0001), do: {:int_or_bin, 8}
  def decode_data_field(0b0010), do: {:int_or_bin, 16}
  def decode_data_field(0b0011), do: {:int_or_bin, 24}
  def decode_data_field(0b0100), do: {:int_or_bin, 32}
  def decode_data_field(0b0101), do: {:real, 32}
  def decode_data_field(0b0110), do: {:int_or_bin, 48}
  def decode_data_field(0b0111), do: {:int_or_bin, 64}
  def decode_data_field(0b1000), do: {:selection_for_readout, 0}
  # 2 digit BCD
  def decode_data_field(0b1001), do: {:bcd, 8}
  # 4 digit BCD
  def decode_data_field(0b1010), do: {:bcd, 16}
  # 6 digit BCD
  def decode_data_field(0b1011), do: {:bcd, 24}
  # 8 digit BCD
  def decode_data_field(0b1100), do: {:bcd, 32}
  def decode_data_field(0b1101), do: {:variable_length, :variable_length}
  # 12 digit BCD
  def decode_data_field(0b1110), do: {:bcd, 48}

  def decode_data_field(0b1111),
    do: raise("unexpected special function coding, this should have been handled already")

  def encode_data_field(:no_data, 0), do: 0b0000
  def encode_data_field(:int_or_bin, 8), do: 0b0001
  def encode_data_field(:int_or_bin, 16), do: 0b0010
  def encode_data_field(:int_or_bin, 24), do: 0b0011
  def encode_data_field(:int_or_bin, 32), do: 0b0100
  def encode_data_field(:real, 32), do: 0b0101
  def encode_data_field(:int_or_bin, 48), do: 0b0110
  def encode_data_field(:int_or_bin, 64), do: 0b0111
  def encode_data_field(:selection_for_readout, 0), do: 0b1000
  # 2 digit BCD
  def encode_data_field(:bcd, 8), do: 0b1001
  # 4 digit BCD
  def encode_data_field(:bcd, 16), do: 0b1010
  # 6 digit BCD
  def encode_data_field(:bcd, 24), do: 0b1011
  # 8 digit BCD
  def encode_data_field(:bcd, 32), do: 0b1100
  def encode_data_field(:variable_length, :variable_length), do: 0b1101
  # 12 digit BCD
  def encode_data_field(:bcd, 48), do: 0b1110

  # function field to atom
  def decode_function_field(0b00), do: :instantaneous
  def decode_function_field(0b01), do: :maximum
  def decode_function_field(0b10), do: :minimum
  def decode_function_field(0b11), do: :value_during_error_state

  def encode_function_field(:instantaneous), do: 0b00
  def encode_function_field(:maximum), do: 0b01
  def encode_function_field(:minimum), do: 0b10
  def encode_function_field(:value_during_error_state), do: 0b11
end
