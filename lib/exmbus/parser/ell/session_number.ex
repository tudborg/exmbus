defmodule Exmbus.Parser.Ell.SessionNumber do
  @moduledoc """
  This module represents the Session Number in the ELL layer.
  """
  defstruct encryption: nil,
            minutes: nil,
            session: nil

  @doc """
  Decode Session Number of ELL.
  Section 13.2.11 of EN 13757-4:2019
  """
  def decode(<<d, c, b, a>>) do
    # convert LE to BE:
    <<enc::3, minutes::25, session::4>> = <<a, b, c, d>>

    mode =
      case enc do
        0b000 ->
          :none

        0b001 ->
          :aes_128_ctr

        enc ->
          throw({:error, {:reserved_ell_session_encryption_mode, enc}})
      end

    {:ok,
     %__MODULE__{
       # encryption mode
       encryption: mode,
       # number of minutes since meter start
       minutes: minutes,
       # inter-minute session
       session: session
     }}
  catch
    {:error, _} = e -> e
  end

  def encode(%__MODULE__{encryption: mode, minutes: m, session: s}) do
    enc =
      case mode do
        :none -> 0b000
        :aes_128_ctr -> 0b001
      end

    # BE to LE before we return
    <<a, b, c, d>> = <<enc::3, m::25, s::4>>
    {:ok, <<d, c, b, a>>}
  end
end
