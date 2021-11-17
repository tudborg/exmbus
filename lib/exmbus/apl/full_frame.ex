defmodule Exmbus.Apl.FullFrame do
  alias Exmbus.Apl.DataRecord
  alias Exmbus.Apl.FormatFrame

  defstruct [
    records: [],
    manufacturer_bytes: nil,
  ]

  def format_signature(%__MODULE__{}=ff) do
    ff
    |> FormatFrame.from_full_frame!()
    |> FormatFrame.format_signature()
  end

  def full_frame_crc(%__MODULE__{records: records, manufacturer_bytes: <<>>}) do
    record_bytes =
      records
      |> Enum.map(fn record ->
        {:ok, bytes, _} = DataRecord.unparse(%{}, [record])
        bytes
      end)
      |> Enum.into("")
    {:ok, CRC.crc(:crc_16_en_13757, record_bytes)}
  end
end
