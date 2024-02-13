defmodule DataRecordTest do
  use ExUnit.Case, async: true

  alias Exmbus.Parser.Context
  alias Exmbus.Parser.Apl.DataRecord
  alias Exmbus.Parser.Apl.DataRecord.Header
  alias Exmbus.Parser.Apl.DataRecord.DataInformationBlock
  alias Exmbus.Parser.Apl.DataRecord.ValueInformationBlock

  doctest Exmbus.Parser.Apl.DataRecord, import: true

  describe "Main VIFE-code extension table (0xFD)" do
    test "0bE0010111 Error flags" do
      {:ok, record, <<0xFF, 0xFF>>} =
        DataRecord.parse(
          <<0x02, 0xFD, 0x17, 0b00000100, 0b10000000, 0xFF, 0xFF>>,
          %{},
          Context.new()
        )

      assert %DataRecord{
               data: [
                 true,
                 false,
                 false,
                 false,
                 false,
                 false,
                 false,
                 false,
                 false,
                 false,
                 false,
                 false,
                 false,
                 true,
                 false,
                 false
               ],
               header: %Header{
                 dib: %DataInformationBlock{
                   size: 16
                 },
                 vib: %ValueInformationBlock{
                   coding: :type_d,
                   description: :error_flags
                 }
               }
             } = record
    end
  end

  test "Plain Text Units - C.2 EN 13757-3:2018" do
    # Example from Table C.2 — Data record structure for plain text VIF usage
    data_record_bytes = <<
      # DIF means 8 digit BCD value:
      0x0C,
      # VIF means plain text VIF following:
      0xFC,
      # VIFE means "per hour":
      0xA2,
      # VIFE means "* 10^–3":
      0x73,
      # ASCII length means 4 bytes ASCII string following:
      0x04,
      # ASCII string means "igal":
      0x6C,
      0x61,
      0x67,
      0x69,
      # Value = 75420826
      0x26,
      0x08,
      0x42,
      0x75
    >>

    {:ok, data_record, ""} = DataRecord.parse(data_record_bytes, %{}, Context.new())

    assert %DataRecord{
             data: 75_420_826,
             header: %Header{
               dib_bytes: <<0x0C>>,
               vib_bytes: <<0xFC, 0xA2, 0x73, 0x04, 0x6C, 0x61, 0x67, 0x69>>,
               dib: %DataInformationBlock{
                 device: 0,
                 tariff: 0,
                 storage: 0,
                 function_field: :instantaneous,
                 data_type: :bcd,
                 size: 32
               },
               vib: %ValueInformationBlock{
                 description: :plain_text_unit,
                 multiplier: nil,
                 unit: "igal",
                 extensions: [
                   {:per, :interval, :hour},
                   {:multiplicative_correction_factor, 0.001}
                 ],
                 coding: nil,
                 table: :main
               },
               coding: :type_a
             }
           } = data_record

    assert %{value: 75_420.826, unit: "igal/h"} = DataRecord.to_map!(data_record)
  end

  describe "regressions" do
    test "ABB-style energy reading" do
      record = %DataRecord{
        data: 455_224,
        header: %DataRecord.Header{
          dib: %DataInformationBlock{
            device: 0,
            storage: 0,
            tariff: 0,
            function_field: :instantaneous,
            data_type: :bcd,
            size: 48
          },
          vib: %ValueInformationBlock{
            coding: :type_a,
            description: :energy,
            extensions: [record_error: :none],
            multiplier: 10,
            unit: "Wh"
          }
        }
      }

      assert %{value: 4_552_240, unit: "Wh"} = DataRecord.to_map!(record)
    end
  end
end
