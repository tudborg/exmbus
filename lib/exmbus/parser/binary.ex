defmodule Exmbus.Parser.Binary do
  @moduledoc """
  Utility to find and collect bytes in a binary.
  """

  @doc """
  Collect a sequence of bytes where the first bit in each byte
  represents if the next byte is part of the sequence.
  Meaning the returned binary will have the first bit of each byte set, except the last byte.

  ## Examples:

      iex> {:ok, <<0xFF, 0x00>>, <<0x00>>} = collect_by_extension_bit(<<0xFF, 0x00, 0x00>>)

      iex> {:ok, <<0x00>>, <<0x00>>} = collect_by_extension_bit(<<0x00, 0x00>>)

      iex> {:ok, <<0x80, 0x80, 0x00>>, <<0x00>>} = collect_by_extension_bit(<<1::1, 0::7, 1::1, 0::7, 0x00, 0x00>>)
  """
  def collect_by_extension_bit(<<0::1, _::7, _::binary>> = bin) do
    <<block::binary-size(1), rest::binary>> = bin
    {:ok, block, rest}
  end

  def collect_by_extension_bit(<<1::1, _::7, 0::1, _::7, _::binary>> = bin) do
    <<block::binary-size(2), rest::binary>> = bin
    {:ok, block, rest}
  end

  def collect_by_extension_bit(<<1::1, _::7, 1::1, _::7, 0::1, _::7, _::binary>> = bin) do
    <<block::binary-size(3), rest::binary>> = bin
    {:ok, block, rest}
  end

  def collect_by_extension_bit(
        <<1::1, _::7, 1::1, _::7, 1::1, _::7, 0::1, _::7, _::binary>> = bin
      ) do
    <<block::binary-size(4), rest::binary>> = bin
    {:ok, block, rest}
  end

  def collect_by_extension_bit(bin) do
    # our pre-defined patterns didn't match, so we'll try a generic approach.
    # we start at 4 bytes, because we know the first 4 bytes are not a match
    # due to the above function clauses.
    generic_collect_by_extension_bit(bin, 4)
  end

  defp generic_collect_by_extension_bit(bin, byte_len) do
    case bin do
      <<_::binary-size(byte_len), 0::1, _::7, _::binary>> ->
        <<block::binary-size(byte_len + 1), rest::binary>> = bin
        {:ok, block, rest}

      <<_::binary-size(byte_len), 1::1, _::7, _::binary>> ->
        generic_collect_by_extension_bit(bin, byte_len + 1)
    end
  end
end
