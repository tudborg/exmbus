defmodule Exmbus.Parser.DataType.PeriodicDate do
  @moduledoc """
  Represents a periodic date data type.

  Returned by the parser when decoding a Type G data type with periodicity.

  When a component (year, month, or day) is periodic (wildcard), it is represented as `nil`.
  """

  defstruct [:year, :month, :day]

  @doc """
  Creates a new PeriodicDate struct.
  """
  @spec new(integer() | nil, integer() | nil, integer() | nil) :: {:ok, %__MODULE__{}}
  def new(year, month, day)
      when (is_integer(year) or is_nil(year)) and (is_integer(month) or is_nil(month)) and
             (is_integer(day) or is_nil(day)) do
    {:ok, %__MODULE__{year: year, month: month, day: day}}
  end

  def new(year, month, day) do
    {:error, {:badarg, [year, month, day]}}
  end

  @doc """
  Creates a new PeriodicDate struct, raising an error on invalid input.
  """
  @spec new!(integer() | nil, integer() | nil, integer() | nil) :: %__MODULE__{}
  def new!(year, month, day) do
    case new(year, month, day) do
      {:ok, periodic_date} -> periodic_date
      {:error, reason} -> raise ArgumentError, "Invalid PeriodicDate: #{inspect(reason)}"
    end
  end

  defimpl String.Chars do
    def to_string(%{year: year, month: month, day: day}) do
      year_str =
        if is_nil(year),
          do: "YYYY",
          else: year |> Integer.to_string() |> String.pad_leading(4, "0")

      month_str =
        if is_nil(month),
          do: "MM",
          else: month |> Integer.to_string() |> String.pad_leading(2, "0")

      day_str =
        if is_nil(day),
          do: "DD",
          else: day |> Integer.to_string() |> String.pad_leading(2, "0")

      "#{year_str}-#{month_str}-#{day_str}"
    end
  end
end
