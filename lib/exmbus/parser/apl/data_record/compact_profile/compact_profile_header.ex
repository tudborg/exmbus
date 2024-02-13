defmodule Exmbus.Parser.Apl.DataRecord.CompactProfile.CompactProfileHeader do
  alias Exmbus.Parser.Apl.DataRecord.DataInformationBlock

  defstruct increment_mode: nil,
            spacing: nil,
            # data type, e.g. int_or_bin, real, bcd
            data_type: nil,
            # the size of the value in bits
            size: nil,
            # coding (e.g. type_b, type_c, etc.) See DataInformationBlock for more information.
            coding: nil

  def parse(
        <<increment_mode_bits::2, spacing_unit_bits::2, element_size::4, spacing_value_byte,
          rest::binary>>
      ) do
    increment_mode =
      case increment_mode_bits do
        00 -> :absolute_value
        01 -> :increments
        10 -> :decrements
        11 -> :signed_difference
      end

    # the values 0xD and 0xF are now allowed in the element_size of a compact profile,
    # so we check for them and raise if we see then:
    if element_size in [0xD, 0xF] do
      raise "Invalid element size in compact profile: #{element_size}. 0xD and 0xF are not allowed as element size in compact profiles."
    end

    # the element_size determines how large each element is,
    # and is structured like the data_field of the DIF.
    {data_type, size} = DataInformationBlock.decode_data_field(element_size)

    # spacing is the distance between each element.
    # this is custom to the compact profile.
    spacing =
      case {spacing_unit_bits, spacing_value_byte} do
        # Elements of an array, not spacing in time:
        {unit, 0x00} -> {:array, unit + 1}
        # Number of days, hours, minutes or seconds between each value:
        {0b00, value} when value < 251 -> {value, :second}
        {0b01, value} when value < 251 -> {value, :minute}
        {0b10, value} when value < 251 -> {value, :hour}
        {0b11, value} when value < 251 -> {value, :day}
        # Reserved for future use:
        {unit, value} when value in [251, 252] -> {:reserved, {value, unit}}
        # month and half-month spacings have special values:
        {0b11, 253} -> {1, :half_month}
        {unit, 253} -> {:reserved, {253, unit}}
        {0b11, 254} -> {1, :month}
        {0b00, 254} -> {:reserved, {254, 0b00}}
        {0b01, 254} -> {6, :month}
        {0b10, 254} -> {3, :month}
        # final value reserved:
        {unit, 255} -> {:reserved, {255, unit}}
      end

    coding =
      case {data_type, increment_mode} do
        {:int_or_bin, :increments} -> :type_c
        {:int_or_bin, :decrements} -> :type_c
        {:int_or_bin, :absolute_value} -> :type_b
        {:int_or_bin, :signed_difference} -> :type_b
        _ -> DataInformationBlock.default_coding(data_type)
      end

    header = %__MODULE__{
      increment_mode: increment_mode,
      data_type: data_type,
      size: size,
      spacing: spacing,
      coding: coding
    }

    {:ok, header, rest}
  end
end
