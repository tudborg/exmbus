defmodule Exmbus.Parser.Tpl.Status do
  @moduledoc """
  EN 13757-7:2018 (E) - 7.5.6 Status byte in meter messages

  More details about the error state of the meter can be provided in the M-Bus
  application protocol of the meter response (refer to EN 13757-3:2018, Annex E).
  """

  @type application_status ::
          :no_error | :application_busy | :any_application_error | :abnormal_condition_or_alarm

  @type t :: %__MODULE__{
          manufacturer_status: 0..7,
          temporary_error: boolean(),
          permanent_error: boolean(),
          low_power: boolean(),
          application_status: application_status()
        }

  defstruct manufacturer_status: 0,
            temporary_error: false,
            permanent_error: false,
            low_power: false,
            application_status: :no_error

  def decode(<<man_status::size(3), t::size(1), p::size(1), l::size(1), app::size(2)>>) do
    application_status =
      case app do
        0b00 -> :no_error
        0b01 -> :application_busy
        0b10 -> :any_application_error
        0b11 -> :abnormal_condition_or_alarm
      end

    %__MODULE__{
      manufacturer_status: man_status,
      temporary_error: int_to_bool(t),
      permanent_error: int_to_bool(p),
      low_power: int_to_bool(l),
      application_status: application_status
    }
  end

  def encode(%__MODULE__{
        manufacturer_status: man_status,
        temporary_error: t,
        permanent_error: p,
        low_power: l,
        application_status: a
      }) do
    abin =
      case a do
        :no_error -> 0b00
        :application_busy -> 0b01
        :any_application_error -> 0b10
        :abnormal_condition_or_alarm -> 0b11
      end

    <<man_status::size(3), bool_to_int(t)::size(1), bool_to_int(p)::size(1),
      bool_to_int(l)::size(1), abin::size(2)>>
  end

  defp bool_to_int(true), do: 1
  defp bool_to_int(false), do: 0
  defp int_to_bool(1), do: true
  defp int_to_bool(0), do: false
end
