defmodule Exmbus.Apl.FullFrame do
  defstruct [
    records: [],
    manufacturer_bytes: nil,
  ]

  alias Exmbus.Apl.FormatFrame

  def format_signature(%__MODULE__{}=ff) do
    ff
    |> FormatFrame.from_full_frame!()
    |> FormatFrame.format_signature()
  end
end
