defmodule Exmbus.Debug do

  def u8_to_hex_str(u) when u >= 0 and u <= 255 do
    "0x#{Integer.to_string(u, 16)}"
  end

  def u8_to_binary_str(<<>>) do
    ""
  end
  def u8_to_binary_str(<<b::1, rest::bitstring>>) do
    "#{b}#{u8_to_binary_str(rest)}"
  end
  def u8_to_binary_str(n) when is_integer(n) do
    "0b#{u8_to_binary_str(<<n>>)}"
  end

end
