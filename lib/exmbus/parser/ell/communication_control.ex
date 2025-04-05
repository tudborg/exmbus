defmodule Exmbus.Parser.Ell.CommunicationControl do
  @moduledoc """
  This module represents the Communication Control (CC) field in the ELL layer.
  """
  defstruct bidirectional: nil,
            response_delay: nil,
            synchronized: nil,
            hop_count: nil,
            # true for alarms and other critical data.
            priority: nil,
            accessibility: nil,
            repeated_access: nil

  @doc """
  Decode the CC (Communication Control) field from the ELL.

    iex> decode_cc(<<0b00000000>>)
    {:ok, %{bidirectional: false}}
    iex> decode_cc(<<0b10000000>>)
    {:ok, %{bidirectional: true}}

  """
  def decode(<<b::1, d::1, s::1, h::1, p::1, a::1, r::1, x::1>>) do
    # response delay from 13.2.7.3 table 51
    response_delay =
      case {d, x} do
        {0, 0} -> :slow_delay
        {1, 0} -> :fast_delay
        {0, 1} -> :extended_delay
        {1, 1} -> :reserved
      end

    {:ok,
     %__MODULE__{
       bidirectional: b == 1,
       response_delay: response_delay,
       # according to 12.6.2
       synchronized: s == 1,
       hop_count: h == 1,
       # true for alarms and other critical data.
       priority: p == 1,
       accessibility: a == 1,
       repeated_access: r == 1
     }}
  end

  def encode(%__MODULE__{} = cc) do
    {d, x} =
      case cc.response_delay do
        :slow_delay -> {0, 0}
        :fast_delay -> {1, 0}
        :extended_delay -> {0, 1}
        :reserved -> {1, 1}
      end

    {:ok,
     <<
       bool_to_int(cc.bidirectional)::1,
       d::1,
       bool_to_int(cc.synchronized)::1,
       bool_to_int(cc.hop_count)::1,
       bool_to_int(cc.priority)::1,
       bool_to_int(cc.accessibility)::1,
       bool_to_int(cc.repeated_access)::1,
       x::1
     >>}
  end

  defp bool_to_int(true), do: 1
  defp bool_to_int(false), do: 0
end
