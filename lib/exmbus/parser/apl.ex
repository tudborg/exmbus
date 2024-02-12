defmodule Exmbus.Parser.Apl do
  alias Exmbus.Parser.Tpl
  alias Exmbus.Parser.Apl.FullFrame
  alias Exmbus.Parser.Apl.FormatFrame
  alias Exmbus.Parser.Apl.CompactFrame
  alias Exmbus.Parser.Apl.Unparsed

  @doc """
  Decode the Application Layer and return one of the Apl frame structs.

  The Application Layer consists of N number of records where N >= 0,
  and some optional manufacturer specific data.

  The function assumes that the entire input is the APL layer data.
  """
  def parse(bin, opts, %{apl: nil} = ctx) do
    with {:ok, ctx, ""} <- Unparsed.parse(bin, opts, ctx),
         {:ok, ctx} <- Unparsed.decrypt(opts, ctx) do
      parse_records(opts, ctx)
    end
  end

  # assume decrypted apl bytes as first argument, parse data fields
  # an return an {:ok, Apl+ctx}
  defp parse_records(opts, %{tpl: %Tpl{frame_type: :full_frame}, apl: %{} = apl} = ctx) do
    # NOTE:
    # Should we possibly calculate the format signature here and attach it to the FullFrame struct?
    # That way we don't need the expensive unparse operation to get the format signature,
    # BUT we'd calculate it on every single parse? Option to turn off maybe?
    FullFrame.parse(apl.plain_bytes, opts, ctx)
  end

  defp parse_records(opts, %{tpl: %Tpl{frame_type: :format_frame}, apl: %{} = apl} = ctx) do
    FormatFrame.parse(apl.plain_bytes, opts, ctx)
  end

  defp parse_records(opts, %{tpl: %Tpl{frame_type: :compact_frame}, apl: %{} = apl} = ctx) do
    CompactFrame.parse(apl.plain_bytes, opts, ctx)
  end
end
