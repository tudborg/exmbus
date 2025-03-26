defmodule Parser.Apl.DataRecord.CompactProfileTest do
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
  alias Exmbus.Parser.Context
  use ExUnit.Case, async: true

  # in these tests we only look at APL full frame bytes
  # so we use the full frame parsing handler
  # and the compact profile expand handler.
  def parsing_context() do
    Context.new(
      handlers: [
        &Exmbus.Parser.Apl.FullFrame.parse/1,
        &Exmbus.Parser.Apl.FullFrame.expand_compact_profiles/1
      ]
    )
  end

  test "compact profile with register numbers - orthogonal VIFE 0x1E - F.2.6" do
    apl_bytes =
      [
        # base time, storage=32, tariff=0
        "868081006D0000A0411135",
        # base value, storage=32, tariff=1
        "8490810003F0490200",
        # profile 1 (2 values: storage 33 and 34) storage=32, tariff=1:
        "8D908100831E0A34FEA0860100D0FB0100",
        # base time, storage=35, tariff=0
        "C68181006D0B0C8D59130C",
        # base value, storage=35, tariff=1
        "C491810003905F0100",
        # base time, storage=36, tariff=0
        "868281006D00008041140D",
        # base value, storage=36, tariff=1
        "849281000350C30000",
        # profile 2 (1 value: storage 37) storage=37, tariff=1:
        "8D928100831E0634FE00710200"
      ]
      |> Enum.join()
      |> Base.decode16!()

    assert {:ok, ctx} = Exmbus.parse(apl_bytes, parsing_context())
    assert %{errors: [], warnings: []} = ctx

    assert [
             %DataRecord{
               header: %{dib: %{storage: 32, tariff: 0}},
               data: ~N[2010-01-01 00:00:00]
             },
             %DataRecord{
               header: %{dib: %{storage: 32, tariff: 1}},
               data: 150_000
             },
             %DataRecord{
               header: %{dib: %{storage: 33, tariff: 0}},
               data: ~N[2010-02-01 00:00:00]
             },
             %DataRecord{
               header: %{dib: %{storage: 33, tariff: 1}},
               data: 100_000
             },
             %DataRecord{
               header: %{dib: %{storage: 34, tariff: 0}},
               data: ~N[2010-03-01 00:00:00]
             },
             %DataRecord{
               header: %{dib: %{storage: 34, tariff: 1}},
               data: 130_000
             },
             %DataRecord{
               header: %{dib: %{storage: 35, tariff: 0}},
               data: ~N[2010-03-25 13:12:11]
             },
             %DataRecord{
               header: %{dib: %{storage: 35, tariff: 1}},
               data: 90_000
             },
             %DataRecord{
               header: %{dib: %{storage: 36, tariff: 0}},
               data: ~N[2010-04-01 00:00:00]
             },
             %DataRecord{
               header: %{dib: %{storage: 36, tariff: 1}},
               data: 50_000
             },
             %DataRecord{
               header: %{dib: %{storage: 37, tariff: 0}},
               data: ~N[2010-05-01 00:00:00]
             },
             %DataRecord{
               header: %{dib: %{storage: 37, tariff: 1}},
               data: 160_000
             }
           ] = ctx.apl.records
  end

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

    assert {:ok, ctx} = Exmbus.parse(apl_bytes, parsing_context())

    assert [
             # base time:
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 8,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 32
                 },
                 vib: %DataRecord.ValueInformationBlock{
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
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 8,
                   function_field: :instantaneous,
                   data_type: :bcd,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
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

    assert {:ok, ctx} = Exmbus.parse(apl_bytes, parsing_context())

    assert [
             # base
             %DataRecord{
               header: %DataRecord.Header{
                 dib_bytes: <<132, 4>>,
                 vib_bytes: "m",
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 8,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 32
                 },
                 vib: %DataRecord.ValueInformationBlock{
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
             %DataRecord{
               header: %DataRecord.Header{
                 dib_bytes: <<139, 4>>,
                 vib_bytes: <<21>>,
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 8,
                   function_field: :instantaneous,
                   data_type: :bcd,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
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
