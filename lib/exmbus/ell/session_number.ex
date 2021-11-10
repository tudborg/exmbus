defmodule Exmbus.Ell.SessionNumber do
  defstruct [
    encryption: nil,
    minutes: nil,
    session: nil,
  ]

  @doc """
  Decode Session Number of ELL.
  Section 13.2.11 of EN 13757-4:2019
  """
  def decode(<<d,c,b,a>>) do
    # convert LE to BE:
    <<enc::3, minutes::25, session::4>> = <<a,b,c,d>>
    mode =
      case enc do
        0b000 -> :none
        0b001 -> :aes_128_ctr
        enc -> raise "ELL session number encryption mode #{enc} is reserved for future use, see 13.2.11 of EN 13757-4:2019"
      end
    {:ok,
      %__MODULE__{
        encryption: mode, # encryption mode
        minutes: minutes, # number of minutes since meter start
        session: session, # inter-minute session
      }}

  end

  def encode(%__MODULE__{encryption: mode, minutes: m, session: s}) do
    enc =
      case mode do
        :none -> 0b000
        :aes_128_ctr -> 0b001
      end
    # BE to LE before we return
    <<a,b,c,d>> = <<enc::3, m::25, s::4>>
    {:ok, <<d,c,b,a>>}
  end

end
