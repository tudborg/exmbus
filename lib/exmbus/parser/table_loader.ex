defmodule Exmbus.Parser.TableLoader do
  @moduledoc """
  Load a CSV file into a table.
  Used to load CSVs at compile time for meta programming.
  """

  require Logger

  NimbleCSV.define(Exmbus.Parser.TableLoader.TableCSV, separator: ";", escape: "\"")

  def from_file!(path) do
    path
    |> File.stream!()
    |> from_enumerable!()
  end

  def from_enumerable!(stream) do
    stream
    |> Exmbus.Parser.TableLoader.TableCSV.parse_stream()
    |> Enum.map(&auto_format_columns/1)
    |> Enum.map(&List.to_tuple/1)
  end

  defp auto_format_columns(cols) do
    Enum.map(cols, fn col ->
      col
      |> String.trim()
      |> auto_format_column()
    end)
  end

  defp auto_format_column("hex:" <> hex), do: parse_hex!(hex)
  defp auto_format_column("int:" <> int), do: parse_int!(int)
  defp auto_format_column("float:" <> float), do: parse_float!(float)
  defp auto_format_column("str:" <> str), do: str
  defp auto_format_column("atom:" <> name), do: String.to_atom(name)
  defp auto_format_column(":" <> name), do: auto_format_column("atom:" <> name)

  defp auto_format_column(str) do
    cond do
      # Is a range?
      Regex.match?(~r"\.\.", str) ->
        case String.split(str, "..") do
          [low, high] ->
            {:range, auto_format_column(low), auto_format_column(high)}
        end

      # Looks like a float?
      Regex.match?(~r"^\d+\.\d+$", str) ->
        auto_format_column("float:" <> str)

      # Looks like an int?
      Regex.match?(~r"^\d+$", str) ->
        auto_format_column("int:" <> str)
        parse_int!(str)

      # Looks like hex?
      Regex.match?(~r"^0x[0-9A-Fa-f]+$", str) ->
        auto_format_column("hex:" <> str)

      true ->
        str
    end
  end

  defp parse_float!(str) do
    case Float.parse(str) do
      :error -> raise "Not a float: #{inspect(str)}"
      {float, ""} -> float
      {_, _tail} -> raise "Not a float: #{inspect(str)}"
    end
  end

  defp parse_int!(str) do
    case Integer.parse(str) do
      :error -> raise "Not an integer: #{inspect(str)}"
      {integer, ""} -> integer
      {_, _tail} -> raise "Not an integer: #{inspect(str)}"
    end
  end

  defp parse_hex!("0x" <> str), do: parse_hex!(str)
  defp parse_hex!(str), do: Base.decode16!(str)
end
