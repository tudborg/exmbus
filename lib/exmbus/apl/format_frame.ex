defmodule Exmbus.Apl.FormatFrame do
  defstruct [
    headers: nil,
  ]

  alias Exmbus.Apl.FullFrame
  alias Exmbus.Apl.DataRecord.Header

  def from_full_frame!(%FullFrame{records: records}) do
    headers =
      records
      |> Enum.map(&(&1.header))
    %__MODULE__{headers: headers}
  end

  def format_signature(%__MODULE__{headers: headers}) when is_list(headers) do
    headers
    |> Enum.map(fn header ->
      {:ok, header_bin, []} = Header.unparse(%{}, [header])
      header_bin
    end)
    |> Enum.into("")
    |> format_signature()
  end

  def format_signature(bytes) when is_binary(bytes) do
    {:ok, CRC.crc(:crc_16_en_13757, bytes)}
  end
end
