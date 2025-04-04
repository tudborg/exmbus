defmodule Exmbus.Parser.IdentificationNo do
  @moduledoc """
  Decode/Encode identification number (BCD) to/from binary representation.

  The identification number is a 4-byte binary representation of a BCD number.

  It can optionally contain `F` representing a wildcard digit.

      iex> decode(<<0x78, 0x56, 0x34, 0x12>>)
      {:ok, "12345678"}

      iex> decode(<<0x78, 0x56, 0x34, 0xF2>>)
      {:ok, "F2345678"}


      iex> encode("12345678")
      {:ok, <<0x78, 0x56, 0x34, 0x12>>}

      iex> encode(12345678)
      {:ok, <<0x78, 0x56, 0x34, 0x12>>}
  """

  @doc """
  Decode from the binary representation of the identification number (BCD)
  """
  def decode(<<d, c, b, a>>) do
    decoded = Base.encode16(<<a, b, c, d>>)
    {:ok, decoded}
  end

  @doc """
  Encode the identification number to binary representation (BCD)
  """
  def encode(identification_no) when is_binary(identification_no) do
    with {:ok, <<d, c, b, a>>} <- Base.decode16(identification_no) do
      {:ok, <<a, b, c, d>>}
    else
      :error -> {:error, :invalid_identification_no, identification_no}
    end
  end

  def encode(identification_no) when is_integer(identification_no) do
    encode(Integer.to_string(identification_no))
  end
end
