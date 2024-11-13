defmodule Exmbus.Parser.Apl do
  alias Exmbus.Parser.Context
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
    {:next, Context.prepend_handlers(ctx, [&FullFrame.parse/1])}
  end

  def parse(%{tpl: %{frame_type: :format_frame}} = ctx) do
    {:next, Context.prepend_handlers(ctx, [&FormatFrame.parse/1])}
  end

  def parse(%{tpl: %{frame_type: :compact_frame}} = ctx) do
    {:next, Context.prepend_handlers(ctx, [&CompactFrame.parse/1])}
  end
end
