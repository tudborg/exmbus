defmodule Exmbus.TableLoader do
  NimbleCSV.define(TableCSV, separator: ";", escape: "\"")

  def from_file!(dir, filename) do
    Path.join(dir, filename)
    |> File.stream!()
    |> TableCSV.parse_stream()
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

  defp auto_format_column("0x" <> hex), do: Base.decode16!(hex)
  defp auto_format_column("hex:" <> hex), do: Base.decode16!(hex)
  defp auto_format_column("int:" <> int), do: parse_int!(int)
  defp auto_format_column("float:" <> float), do: parse_float!(float)
  defp auto_format_column("str:" <> str), do: str
  defp auto_format_column("atom:" <> name), do: String.to_atom(name)
  defp auto_format_column(":" <> name), do: String.to_atom(name)
  defp auto_format_column(str) do
    cond do
      Regex.match?(~r"^\d+.\d+$", str) -> parse_float!(str)
      Regex.match?(~r"^\d+$", str) -> parse_int!(str)
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
end
