defmodule Exmbus.Parser.Manufacturer do
  @moduledoc """
  Implements encode/decode for the 2-byte manufacturer flag ID
  """

  @doc """
  Decode from binary to string representation of manufacturer

    iex> decode(<<0x93, 0x44>>)
    {:ok, "QDS"}
  """
  def decode(<<man::little-size(16)>>) do
    {:ok, int_to_manufacturer(man)}
  end

  @doc """
  Encode 3-letter manufacturer

    iex> {:ok, <<0x93, 0x44>>} = encode("QDS")
  """
  def encode(<<_, _, _>> = m) do
    i = manufacturer_to_int(m)
    {:ok, <<i::little-size(16)>>}
  end

  # NOTE: special handling of wildcard manufacturer 0x7FFF ? EN 13757-7:2018 section 7.5.2 Manufacturer identification?
  defp int_to_manufacturer(n) when is_integer(n) do
    <<a::size(5), b::size(5), c::size(5)>> = <<n::15>>
    <<a + 64, b + 64, c + 64>>
  end

  defp manufacturer_to_int(<<a, b, c>>) do
    (a - 64) * 32 * 32 +
      (b - 64) * 32 +
      (c - 64)
  end
end
