defmodule FeatureCompatibility.LimitExceedTest do
  @moduledoc """
  Tests the parsing of limit exceed VIFEs and their use-cases.
  """
  alias Exmbus.Parser.Apl.FullFrame
  use ExUnit.Case, async: true

  test "E101 ufnn Duration of limit exceed os parseable" do
    apl = "0C13252110004C1316400900426C1F3C02BB560000326CFFFF046D30153036" |> Base.decode16!()

    ctx = %Exmbus.Parser.Context{bin: apl}
    {:next, ctx} = FullFrame.parse(ctx)

    limit_exceed_record =
      Enum.find(ctx.apl.records, fn record ->
        Enum.any?(record.header.vib.extensions, &(elem(&1, 0) == :duration_of_limit_exceed))
      end)

    assert limit_exceed_record != nil

    assert [{:duration_of_limit_exceed, :lower, :last, :hour}] =
             limit_exceed_record.header.vib.extensions
  end
end
