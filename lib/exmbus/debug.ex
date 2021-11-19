defmodule Exmbus.Debug do

  def u8_to_hex_str(u) when u >= 0 and u <= 255 do
    Integer.to_string(u, 16)
  end

  def u8_to_binary_str(n) when is_integer(n), do: u8_to_binary_str(<<n>>)
  def u8_to_binary_str(<<>>), do: ""
  def u8_to_binary_str(<<b::1, rest::bitstring>>), do: "#{b}#{u8_to_binary_str(rest)}"

  def bin_to_hex(bin) when is_binary(bin) do
    "" <>
      (
      bin
      |> :binary.bin_to_list()
      |> Enum.map(&u8_to_hex_str/1)
      |> Enum.map(&String.pad_leading(&1, 2, "0"))
      |> Enum.join("")
      )
  end

  def bin_to_binary_str(bin) when is_binary(bin) do
    bin
    |> :binary.bin_to_list()
    |> Enum.map(&u8_to_binary_str/1)
    |> Enum.join(" ")
  end

end
