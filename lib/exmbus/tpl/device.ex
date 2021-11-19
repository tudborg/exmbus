defmodule Exmbus.Tpl.Device do
  @table Exmbus.TableLoader.from_file!(__DIR__, "device.csv")

  def encode!(value) do
    case encode(value) do
      {:ok, value} -> value
      {:error, reason} -> raise "encode/1 failed with reason=#{inspect reason}"
    end
  end

  def decode!(byte) do
    case decode(byte) do
      {:ok, value} -> value
      {:error, reason} -> raise "decode/1 failed with reason=#{inspect reason}"
    end
  end

  @doc """
  decode a device byte into internal atom
  """
  @spec decode(binary()) :: {:ok, atom()} | {:error, reason :: any()}
  Enum.each(@table, fn {byte, atom, _} ->
    case byte do
      {:range, <<n_low>>, <<n_high>>} ->
        def decode(<<n>>) when n >= unquote(n_low) and n <= unquote(n_high), do: {:ok, {unquote(atom), n}}
      byte ->
        def decode(unquote(byte)), do: {:ok, unquote(atom)}
    end
  end)
  def decode(byte) when is_binary(byte) and byte_size(byte) == 1, do: {:error, {:unknown_device_type_byte, byte}}

  @doc """
  encode an internal device atom into it's mbus byte
  """
  @spec encode(atom) :: {:ok, binary()} | {:error, reason :: any()}
  Enum.each(@table, fn {byte, atom, _} ->
    case byte do
      {:range, <<n_low>>, <<n_high>>} ->
        for i <- n_low..n_high do
          def encode({unquote(atom), unquote(i)}), do: {:ok, unquote(<<i>>)}
        end
      byte ->
        def encode(unquote(atom)), do: {:ok, unquote(byte)}
    end
  end)
  def encode(unknown), do: {:error, {:unknown_value, unknown}}

  @doc """
  return a string describing the device (either byte or atom)
  """
  @spec format(atom | binary) :: String.t()
  Enum.each(@table, fn {byte, atom, description} ->
    range =
      case byte do
        {:range, <<byte_low>>, <<byte_high>>} ->
          byte_low..byte_high
        <<byte>> ->
          byte..byte
      end
    for i <- range do
      def format(unquote(<<i>>)), do: unquote(description)
    end
    def format(unquote(atom)), do: unquote(description)
  end)
end
