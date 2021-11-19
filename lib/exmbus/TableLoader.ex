defmodule Exmbus.TableLoader do
  require Logger
  NimbleCSV.define(TableCSV, separator: ";", escape: "\"")

  def from_file!(dir, filename) do
    Path.join(dir, filename)
    |> File.stream!()
    |> TableCSV.parse_stream()
    |> Enum.map(&auto_format_columns/1)
    |> Enum.map(&List.to_tuple/1)
  rescue
    e ->
      Logger.error("Failed #{__MODULE__}.from_file!(#{inspect dir}, #{inspect filename})\n#{e.message}\n#{Exception.format_stacktrace(__STACKTRACE__)}")
      reraise e, __STACKTRACE__
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
  defp auto_format_column(":" <> name), do: String.to_atom(name)
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
        parse_float!(str)
      # Looks like an int?
      Regex.match?(~r"^\d+$", str) ->
        parse_int!(str)
      # Looks like hex?
      Regex.match?(~r"^0x[0-9A-Fa-f]+$", str) ->
        parse_hex!(str)
      true -> str
    end
  end

  defp parse_float!(str) do
    case Float.parse(str) do
      :error -> raise "Not a float: #{inspect str}"
      {float, ""} -> float
      {_, _tail} -> raise "Not a float: #{inspect str}"
    end
  end

  defp parse_int!(str) do
    case Integer.parse(str) do
      :error -> raise "Not an integer: #{inspect str}"
      {integer, ""} -> integer
      {_, _tail} -> raise "Not an integer: #{inspect str}"
    end
  end

  defp parse_hex!("0x" <> str), do: parse_hex!(str)
  defp parse_hex!(str), do: Base.decode16!(str)
end
