defmodule Compatibility.SON.Sontex868Test do
  @moduledoc """
  Test for Sontex HCA 868.

  Datasheet at https://sontex.ch/wp-content/uploads/2022/11/data-sheet-stx-565-566-868-878.pdf

  """
  use ExUnit.Case, async: true

  alias Exmbus.Parser.DataType.PeriodicDate
  alias Exmbus.Parser.Apl.DataRecord
  alias Exmbus.Parser.Context

  # Meter and key information captured by Wise Home for a test device they own.
  @frame "44EE4D1955332816087A9200B025351FF8F999176A2E38DD8C6AC62B8D9453009F42A0828C23F6F0602AAE7101912A309C1570FFD519785FEB5A7AF908515775C9947A6F7EC16214A666E0685BD5FF162A28B32C9F9ED67500ECA19EB4873D837DB219A2E865574A5D0D34E00DE45E0DC3FB2767E5CF7881B674719CC84C8C89D73C55779A7D37DDBD439D6B402B0912BEA8DA52073791488224334C48188AAA7DBD83A0A856657B649C40B809DF325CFA0C39D817466847F4CB83E623BA"
         |> Base.decode16!()

  @key Base.decode16!("1AC8BD4C1421E45C4D11456AC0467A83")

  test "Real world capture" do
    ctx =
      Context.new(opts: [length: false, key: @key])

    assert {:ok, ctx} = Exmbus.parse(@frame, ctx)

    assert %Context{
             dll: %{manufacturer: "SON", identification_no: "28335519", version: 22},
             tpl: %{header: %{access_no: 146, configuration_field: %{mode: 5}}},
             apl: %{records: records, manufacturer_bytes: <<>>}
           } = ctx

    assert [
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 0,
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
               data: ~N[2025-04-07 12:44:00]
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :units_for_hca,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 1,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :date,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_g,
                   table: :main
                 },
                 coding: :type_g
               },
               data: %PeriodicDate{year: nil, month: 1, day: 1}
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 1,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :units_for_hca,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 1,
                   function_field: :maximum,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :flow_temperature,
                   multiplier: 0.01,
                   unit: "°C",
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 48,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :date,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_g,
                   table: :main
                 },
                 coding: :type_g
               },
               data: ~D[2023-11-01]
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 48,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :units_for_hca,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 49,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :date,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_g,
                   table: :main
                 },
                 coding: :type_g
               },
               data: ~D[2023-12-01]
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 49,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :units_for_hca,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 50,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :date,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_g,
                   table: :main
                 },
                 coding: :type_g
               },
               data: ~D[2024-01-01]
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 50,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :units_for_hca,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 51,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :date,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_g,
                   table: :main
                 },
                 coding: :type_g
               },
               data: ~D[2024-02-01]
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 51,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :units_for_hca,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 52,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :date,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_g,
                   table: :main
                 },
                 coding: :type_g
               },
               data: ~D[2024-03-01]
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 52,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :units_for_hca,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 53,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :date,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_g,
                   table: :main
                 },
                 coding: :type_g
               },
               data: ~D[2024-04-01]
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 53,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :units_for_hca,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 54,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :date,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_g,
                   table: :main
                 },
                 coding: :type_g
               },
               data: ~D[2024-05-01]
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 54,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :units_for_hca,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 55,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :date,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_g,
                   table: :main
                 },
                 coding: :type_g
               },
               data: ~D[2024-06-01]
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 55,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :units_for_hca,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 56,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :date,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_g,
                   table: :main
                 },
                 coding: :type_g
               },
               data: ~D[2024-07-01]
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 56,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :units_for_hca,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 57,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :date,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_g,
                   table: :main
                 },
                 coding: :type_g
               },
               data: ~D[2024-08-01]
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 57,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :units_for_hca,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 58,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :date,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_g,
                   table: :main
                 },
                 coding: :type_g
               },
               data: ~D[2024-09-01]
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 58,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :units_for_hca,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 59,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :date,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_g,
                   table: :main
                 },
                 coding: :type_g
               },
               data: ~D[2024-10-01]
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 59,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :units_for_hca,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 60,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :date,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_g,
                   table: :main
                 },
                 coding: :type_g
               },
               data: ~D[2024-11-01]
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 60,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :units_for_hca,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 61,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :date,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_g,
                   table: :main
                 },
                 coding: :type_g
               },
               data: ~D[2024-12-01]
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 61,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :units_for_hca,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 62,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :date,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_g,
                   table: :main
                 },
                 coding: :type_g
               },
               data: ~D[2025-01-01]
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 62,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :units_for_hca,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 63,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :date,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_g,
                   table: :main
                 },
                 coding: :type_g
               },
               data: ~D[2025-02-01]
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 63,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :units_for_hca,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 64,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :date,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_g,
                   table: :main
                 },
                 coding: :type_g
               },
               data: ~D[2025-03-01]
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 64,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :units_for_hca,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 65,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :date,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_g,
                   table: :main
                 },
                 coding: :type_g
               },
               data: ~D[2025-04-01]
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 65,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :units_for_hca,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :real,
                   size: 32
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :manufacturer_specific_encoding,
                   multiplier: nil,
                   unit: nil,
                   extensions: [manufacturer_specific_vife: 45],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_h
               },
               data: 1.0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 2,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :real,
                   size: 32
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :manufacturer_specific_encoding,
                   multiplier: nil,
                   unit: nil,
                   extensions: [manufacturer_specific_vife: 45],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_h
               },
               data: 1.0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :flow_temperature,
                   multiplier: 0.01,
                   unit: "°C",
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 2709
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :external_temperature,
                   multiplier: 0.01,
                   unit: "°C",
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 2622
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 0,
                   function_field: :maximum,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :flow_temperature,
                   multiplier: 0.01,
                   unit: "°C",
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 3373
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 1,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: {:duration_of_tariff, :minute},
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_c,
                   table: :fd
                 },
                 coding: :type_c
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 1,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :date,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_g,
                   table: :main
                 },
                 coding: :type_g
               },
               data: ~D[2000-01-01]
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 1,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 8
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :cumulation_counter,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :fd
                 },
                 coding: :type_b
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 2,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :date,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_g,
                   table: :main
                 },
                 coding: :type_g
               },
               data: ~D[2025-02-10]
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :bcd,
                   size: 24
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :other_software_version_number,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_a,
                   table: :fd
                 },
                 coding: :type_a
               },
               data: 10501
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :manufacturer_specific_encoding,
                   multiplier: nil,
                   unit: nil,
                   extensions: [manufacturer_specific_vife: 44],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 0
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :state_of_parameter_activation,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: :type_c,
                   table: :fd
                 },
                 coding: :type_c
               },
               data: 3232
             }
           ] = records
  end
end
