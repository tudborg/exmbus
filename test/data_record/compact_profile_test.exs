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

    assert [
             # base time:
             %Exmbus.Parser.Apl.DataRecord{
               header: %Exmbus.Parser.Apl.DataRecord.Header{
                 dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 8,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 32
                 },
                 vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                   description: :naive_datetime,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_f,
                   table: :main
                 },
                 coding: :type_f
               },
               data: ~N[2010-01-01 00:00:00]
             },
             # base value:
             %Exmbus.Parser.Apl.DataRecord{
               header: %Exmbus.Parser.Apl.DataRecord.Header{
                 dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 8,
                   function_field: :instantaneous,
                   data_type: :bcd,
                   size: 24
                 },
                 vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                   description: :volume,
                   multiplier: 0.1,
                   unit: "m^3",
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_a
               },
               data: 123_000
             },
             # expanded compact profile:
             %{header: %{dib: %{storage: 9}}, data: ~N[2010-01-01 01:00:00]},
             %{header: %{dib: %{storage: 9}}, data: 123_003},
             %{header: %{dib: %{storage: 10}}, data: ~N[2010-01-01 02:00:00]},
             %{header: %{dib: %{storage: 10}}, data: 123_005},
             %{header: %{dib: %{storage: 11}}, data: ~N[2010-01-01 03:00:00]},
             %{header: %{dib: %{storage: 11}}, data: 123_016}
           ] = ctx.apl.records
  end

  test "inverse compact profile - orthogonal VIFE 0x13 - F.2.8" do
    apl_bytes =
      [
        # base time:
        "84046D00234111",
        # base value:
        "8B0415163012",
        # profile:
        "8D049513056901110203"
      ]
      |> Enum.join()
      |> Base.decode16!()

    assert {:ok, ctx, <<>>} = FullFrame.parse(apl_bytes, %{}, Context.new())

    assert [
             # base
             %Exmbus.Parser.Apl.DataRecord{
               header: %Exmbus.Parser.Apl.DataRecord.Header{
                 dib_bytes: <<132, 4>>,
                 vib_bytes: "m",
                 dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 8,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 32
                 },
                 vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                   description: :naive_datetime,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_f,
                   table: :main
                 },
                 coding: :type_f
               },
               data: ~N[2010-01-01 03:00:00]
             },
             # value
             %Exmbus.Parser.Apl.DataRecord{
               header: %Exmbus.Parser.Apl.DataRecord.Header{
                 dib_bytes: <<139, 4>>,
                 vib_bytes: <<21>>,
                 dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 8,
                   function_field: :instantaneous,
                   data_type: :bcd,
                   size: 24
                 },
                 vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                   description: :volume,
                   multiplier: 0.1,
                   unit: "m^3",
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_a
               },
               data: 123_016
             },
             # expanded compact profile
             %{header: %{dib: %{storage: 9}}, data: ~N[2010-01-01 02:00:00]},
             %{header: %{dib: %{storage: 9}}, data: 123_005},
             %{header: %{dib: %{storage: 10}}, data: ~N[2010-01-01 01:00:00]},
             %{header: %{dib: %{storage: 10}}, data: 123_003},
             %{header: %{dib: %{storage: 11}}, data: ~N[2010-01-01 00:00:00]},
             %{header: %{dib: %{storage: 11}}, data: 123_000}
           ] = ctx.apl.records
  end
end
