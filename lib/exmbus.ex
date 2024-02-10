defmodule Exmbus do
  @moduledoc """
  Documentation for `Exmbus`.
  """

  @doc """
  Calculate the CRC relevant for mbus (crc_16_en_13757)
  """
  def crc!(bytes) when is_binary(bytes) do
    CRC.crc(:crc_16_en_13757, bytes)
  end
end
