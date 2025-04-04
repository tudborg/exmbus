defmodule Exmbus.Parser.Tpl.Device do
  @moduledoc """
  A device type for the TPL header (also used in Wmbus DLL)

  ## Examples

      iex> decode(<<0x03>>)
      {:ok, %Exmbus.Parser.Tpl.Device{id: 3}}

      iex> encode(%Exmbus.Parser.Tpl.Device{id: 3})
      {:ok, <<3>>}

      iex> format(%Exmbus.Parser.Tpl.Device{id: 3})
      "gas"

      iex> format(0x03)
      "gas"
  """

  @device_csv_path Application.app_dir(:exmbus, "priv/device.csv")
  @external_resource @device_csv_path
  @table Exmbus.Parser.TableLoader.from_file!(@device_csv_path)

  @type t :: %__MODULE__{id: 0..255}

  defstruct id: nil

  @doc """
  decode a device byte into a Device struct
  """
  @spec decode(binary()) :: {:ok, atom()}
  def decode(<<id>>), do: {:ok, %__MODULE__{id: id}}

  @doc """
  encode a Device struct into a byte
  """
  @spec encode(atom) :: {:ok, binary()}
  def encode(%__MODULE__{id: id}), do: {:ok, <<id>>}

  @doc """
  return a string describing the Device
  """
  @spec format(0..255 | t()) :: String.t()
  def format(%__MODULE__{id: id}) do
    format(id)
  end

  Enum.each(@table, fn {byte, description} ->
    case byte do
      {:range, <<id_low>>, <<id_high>>} ->
        def format(id)
            when is_integer(id) and id >= unquote(id_low) and id <= unquote(id_high),
            do: unquote(description)

      <<id>> ->
        def format(unquote(id)), do: unquote(description)
    end
  end)

  def format(id) when is_integer(id) and id >= 0 and id <= 255 do
    "unimplemented device #{id}"
  end
end
