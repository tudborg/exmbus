defmodule Exmbus.Debug do
  @moduledoc false

  @doc """
  Convert a byte to a hex string.

  ## Examples:

      iex> to_hex(0)
      "00"

      iex> to_hex(255)
      "FF"

      iex> to_hex(<<0x00>>)
      "00"

      iex> to_hex(<<0x80>>)
      "80"

      iex> to_hex(<<0xFF>>)
      "FF"
  """
  def to_hex(u) when u >= 0 and u <= 255 do
    u
    |> Integer.to_string(16)
    |> String.pad_leading(2, "0")
  end

  def to_hex(bin) when is_binary(bin) do
    "" <>
      (bin
       |> :binary.bin_to_list()
       |> Enum.map_join(&to_hex/1))
  end

  @doc """
  Convert a byte to a binary string.

  ## Examples:

      iex> to_bits(<<0x00>>)
      "00000000"

      iex> to_bits(<<0xFF>>)
      "11111111"

      iex> to_bits(0)
      "00000000"

      iex> to_bits(255)
      "11111111"

      iex> to_bits(1)
      "00000001"
  """
  # byte, but as integer:
  def to_bits(n) when is_integer(n) and n >= 0 and n <= 255, do: to_bits(<<n>>)
  # bitstring:
  def to_bits(<<>>), do: ""
  def to_bits(<<b::1, rest::bitstring>>), do: "#{b}#{to_bits(rest)}"
end
