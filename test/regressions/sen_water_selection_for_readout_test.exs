defmodule Regressions.SENTest do
  alias Exmbus.Parser.Apl.DataRecord
  use ExUnit.Case, async: true

  # this APL contains multiple bad records. We need to ensure we do not crash on parsing it.
  @bad_apl "041357250000046D31915C3804FD211FB5F1C87CB073966F0C928D64762D190000426C3F3C8C01137E23000082016C4138D3013B400200C4016D128A5B388104FD280182046C5F378404137E2300A358DD1F13098E847E0C081F4E573A2445134E1F0000840613C91D0000C406135B1C00008407131F1B0000C40713CD19000084081337190000C4081379180000840913FA170000C409139E1700002F2F"
           |> Base.decode16!()

  describe "Broken APL" do
    test "doesn't crash the parser" do
      assert {:ok, ctx} =
               [
                 bin: @bad_apl,
                 handlers: [&Exmbus.Parser.Apl.parse/1]
               ]
               |> Exmbus.Parser.Context.new()
               |> Exmbus.Parser.parse()

      assert is_list(ctx.apl.records)

      # value/1 and unit/1 should never crash (they can return errors, but never crash)
      for record <- ctx.apl.records do
        DataRecord.to_map(record)
      end
    end
  end
end
