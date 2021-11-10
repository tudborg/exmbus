defmodule Exmbus do
  @moduledoc """
  Documentation for `Exmbus`.
  """

  alias Exmbus.Message
  alias Exmbus.Apl.DataRecord

  def simplified!(bin, opts \\ %{})
  def simplified!(bin, opts) when is_binary(bin) do
    case parse(bin, opts) do
      {:ok, message} -> simplified!(message, opts)
      {:error, reason} -> raise "Failed to convert binary to message, reason=#{inspect reason}"
    end
  end
  def simplified!(%Message{manufacturer: manufacturer, identification_no: identification_no, device: device, version: version, records: records}, _opts) do
    %{
      manufacturer: manufacturer,
      identification_no: identification_no,
      device: device,
      version: version,
      records: case records do
        :encrypted -> :encrypted
        r -> Enum.map(r, &DataRecord.to_map!/1)
      end
    }
  end

  def parse!(bin, opts \\ %{}), do: Message.parse!(bin, opts)
  def parse(bin, opts \\ %{}), do: Message.parse(bin, opts)




end
