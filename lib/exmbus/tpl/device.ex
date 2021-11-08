defmodule Exmbus.Tpl.Device do
  @table Exmbus.TableLoader.from_file!(__DIR__, "device.csv")

  @doc """
  decode a device byte into internal atom
  """
  @spec decode!(binary) :: atom
  Enum.each(@table, fn ({byte, atom, _}) ->
      def decode!(unquote(byte)), do: unquote(atom)
  end)
  @doc """
  encode an internal device atom into it's mbus byte
  """
  @spec encode(atom) :: binary
  Enum.each(@table, fn ({byte, atom, _}) ->
      def encode(unquote(atom)), do: unquote(byte)
  end)
  @doc """
  return a string describing the device (either byte or atom)
  """
  @spec format(atom|binary) :: String.t
  Enum.each(@table, fn ({byte, atom, description}) ->
      def format(unquote(byte)), do: unquote(description)
      def format(unquote(atom)), do: unquote(description)
  end)
end
