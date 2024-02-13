defmodule Exmbus.Parser.Binary do
  @doc """
  Collect a sequence of bytes where the first bit in each byte
  represents if the next byte is part of the sequence.
  Meaning the returned binary will have the first bit of each byte set, except the last byte.

  ## Examples:

      iex> {:ok, <<0xFF, 0x00>>, <<0x00>>} = collect_by_extension_bit(<<0xFF, 0x00, 0x00>>)

      iex> {:ok, <<0x00>>, <<0x00>>} = collect_by_extension_bit(<<0x00, 0x00>>)

      iex> {:ok, <<0x80, 0x80, 0x00>>, <<0x00>>} = collect_by_extension_bit(<<1::1, 0::7, 1::1, 0::7, 0x00, 0x00>>)
  """
  def collect_by_extension_bit(bin) do
    collect_by_extension_bit(bin, 0)
  end

  defp collect_by_extension_bit(bin, byte_len) do
    case bin do
      <<_::binary-size(byte_len), 0::1, _::7, _::binary>> ->
        <<block::binary-size(byte_len + 1), rest::binary>> = bin
        {:ok, block, rest}

      <<_::binary-size(byte_len), 1::1, _::7, _::binary>> ->
        collect_by_extension_bit(bin, byte_len + 1)
    end
  end
end
