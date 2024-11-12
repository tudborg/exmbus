defmodule Exmbus.Parser.Apl do
  alias Exmbus.Parser.Apl.FullFrame
  alias Exmbus.Parser.Apl.FormatFrame
  alias Exmbus.Parser.Apl.CompactFrame

  @doc """
  Decode the Application Layer and return one of the Apl frame structs.

  The Application Layer consists of N number of records where N >= 0,
  and some optional manufacturer specific data.

  The function assumes that the entire input is the APL layer data.
  """
  def parse(%{tpl: %{frame_type: :full_frame}} = ctx) do
    # NOTE:
    # Should we possibly calculate the format signature here and attach it to the FullFrame struct?
    # That way we don't need the expensive unparse operation to get the format signature,
    # BUT we'd calculate it on every single parse? Option to turn off maybe?
    FullFrame.parse(ctx)
  end

  def parse(%{tpl: %{frame_type: :format_frame}} = ctx) do
    FormatFrame.parse(ctx)
  end

  def parse(%{tpl: %{frame_type: :compact_frame}} = ctx) do
    CompactFrame.parse(ctx)
  end
end
