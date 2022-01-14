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

  def format_signature(%__MODULE__{}=frame) do
    frame
    |> header_bytes()
    |> format_signature()
  end

  def format_signature(bytes) when is_binary(bytes) do
    {:ok, Exmbus.crc!(bytes)}
  end

  defp header_bytes(%__MODULE__{headers: headers}) when is_list(headers) do
    headers
    |> Enum.map(fn
        # if we have the header bytes collected already, we can use those
        (%Header{dib_bytes: d, vib_bytes: v}) when is_binary(d) and is_binary(v) ->
          <<d::binary, v::binary>>
        # otherwise we need to try and unparse the headers
        (%Header{dib_bytes: d, vib_bytes: v}=header) when is_nil(d) or is_nil(v) ->
          {:ok, header_bin, []} = Header.unparse(%{}, [header])
      header_bin
    end)
    |> Enum.into("")
  end
end
