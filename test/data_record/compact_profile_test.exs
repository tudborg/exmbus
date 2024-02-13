defmodule DataRecord.CompactProfileTest do
  @moduledoc """
  Compact Profile is a way to encode multiple values into a single data record
  for efficient transfer, typically because there is an even spacing between
  the values (e.g. monthly data for last 12 months)

  There are 3 types of compact profiles described in Annex F of EN 13757-3:2018.

  - "Compact Profile with register numbers"
  - "Compact Profile"
  - "Inverse Compact Profile"

  """
  alias Exmbus.Parser.Apl.DataRecord
  alias Exmbus.Parser.Apl.FullFrame
  alias Exmbus.Parser.Context
  use ExUnit.Case, async: true

  test "compact profile - orthogonal VIFE 0x1F - F.2.7" do
    apl_bytes =
      [
        # base time:
        "84046D00204111",
        # base value:
        "8B0415003012",
        # profile:
        "8D04951F056901030211"
      ]
      |> Enum.join()
      |> Base.decode16!()

    assert {:ok, ctx, <<>>} = FullFrame.parse(apl_bytes, %{}, Context.new())
    records = ctx.apl.records
    [compact_profile_record] = Enum.filter(records, &DataRecord.is_compact_profile?/1)

    timeseries = DataRecord.unpack_compact_profile(compact_profile_record, ctx)

    assert [
             {
               %{header: %{dib: %{storage: 9}}, data: ~N[2010-01-01 01:00:00]},
               %{header: %{dib: %{storage: 9}}, data: 123_003}
             },
             {
               %{header: %{dib: %{storage: 10}}, data: ~N[2010-01-01 02:00:00]},
               %{header: %{dib: %{storage: 10}}, data: 123_005}
             },
             {
               %{header: %{dib: %{storage: 11}}, data: ~N[2010-01-01 03:00:00]},
               %{header: %{dib: %{storage: 11}}, data: 123_016}
             }
           ] = timeseries
  end

  test "inverse compact profile - orthogonal VIFE 0x13 - F.2.8" do
    apl_bytes =
      [
        # base time:
        "84046D00234111",
        # base value:
        "8B0415003012",
        # profile:
        "8D049513056901110203"
      ]
      |> Enum.join()
      |> Base.decode16!()

    assert {:ok, ctx, <<>>} = FullFrame.parse(apl_bytes, %{}, Context.new())
    records = ctx.apl.records
    [compact_profile_record] = Enum.filter(records, &DataRecord.is_compact_profile?/1)

    {:ok, timeseries} = DataRecord.unpack_compact_profile(compact_profile_record, ctx)

    assert [
             {
               %{header: %{dib: %{storage: 9}}, data: ~N[2010-01-01 02:00:00]},
               %{header: %{dib: %{storage: 9}}, data: 123_005}
             },
             {
               %{header: %{dib: %{storage: 10}}, data: ~N[2010-01-01 01:00:00]},
               %{header: %{dib: %{storage: 10}}, data: 123_003}
             },
             {
               %{header: %{dib: %{storage: 11}}, data: ~N[2010-01-01 00:00:00]},
               %{header: %{dib: %{storage: 11}}, data: 123_000}
             }
           ] = timeseries
  end
end
