defmodule Exmbus.Parser.Afl.MessageCounterField do
  @moduledoc """
  AFL Message Counter Field (MCR) as per EN 13757-7:2018
  The Message Counter Field (MCR) is a 4 byte field that contains a counter

  The presence of the filed AFL.MCR depends on the selected Security mode. See 9.4 for details.
  If the Message counter Field is used, the AFL.MCR field shall always be present in the first fragment.
  It shall not be present in any following fragments of the same message.
  If the AFL.MCR is not present, values of the Message counter field in the TPL shall be used for the AFL.MCR.
  """

  def decode(<<mcr::little-size(32)>>) do
    {:ok, mcr}
  end

  def encode(mcr) when is_integer(mcr) do
    <<mcr::little-size(32)>>
  end
end
