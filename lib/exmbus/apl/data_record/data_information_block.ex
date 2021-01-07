defmodule Exmbus.Apl.DataRecord.DataInformationBlock do
  use Bitwise

  @moduledoc """
  Utilities for DIB parsing
  """

  # data field conversion to nicer internal format.
  def decode_data_field(0b0000), do: {nil, :no_data, 0}
  def decode_data_field(0b0001), do: {:type_b, :int_or_bin, 8}
  def decode_data_field(0b0010), do: {:type_b, :int_or_bin, 16}
  def decode_data_field(0b0011), do: {:type_b, :int_or_bin, 24}
  def decode_data_field(0b0100), do: {:type_b, :int_or_bin, 32}
  def decode_data_field(0b0101), do: {:type_h, :real, 32}
  def decode_data_field(0b0110), do: {:type_b, :int_or_bin, 48}
  def decode_data_field(0b0111), do: {:type_b, :int_or_bin, 64}
  def decode_data_field(0b1000), do: {nil, :selection_for_readout, 0}
  def decode_data_field(0b1001), do: {:type_a, :bcd, 8} # 2 digit BCD
  def decode_data_field(0b1010), do: {:type_a, :bcd, 16} # 4 digit BCD
  def decode_data_field(0b1011), do: {:type_a, :bcd, 24} # 6 digit BCD
  def decode_data_field(0b1100), do: {:type_a, :bcd, 32} # 8 digit BCD
  def decode_data_field(0b1101), do: {:lvar, :variable_length, :lvar}
  def decode_data_field(0b1110), do: {:type_a, :bcd, 48} # 12 digit BCD
  def decode_data_field(0b1111), do: raise "unexpected special function coding, this should have been handled already"

  # function field to atom
  def decode_function_field(0b00), do: :instantaneous
  def decode_function_field(0b01), do: :maximum
  def decode_function_field(0b10), do: :minimum
  def decode_function_field(0b11), do: :value_during_error_state

end
