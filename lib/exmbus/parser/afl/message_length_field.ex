defmodule Exmbus.Parser.Afl.MessageLengthField do
  @moduledoc """
  AFL Message Length Field (ML) as per EN 13757-7:2018

  The field AFL.ML (see Table 9) declares the number of bytes following AFL.ML until the end
  of the unfragmented message (excluding Link Layer fields like CRC or checksum).
  The message length shall be calculated before the message is separated in several fragments.

  The AFL.ML Message Length Field shall only be present in the first fragment of a fragmented message
  to indicate the total message length. For unfragmented messages, the field AFL.ML can be disabled.
  """

  def decode(<<mcr::little-size(16)>>) do
    {:ok, mcr}
  end

  def encode(mcr) when is_integer(mcr) do
    <<mcr::little-size(16)>>
  end
end
