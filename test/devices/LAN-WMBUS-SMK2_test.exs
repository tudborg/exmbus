defmodule Devices.LAN_WMBUS_SMK2Test do
  use ExUnit.Case, async: true

  @moduledoc """
  Tests for the LAN-WMBUS-SMK2 smoke detector device.
  At time of writing, document stored at https://lansensystems.com/umbraco/surface/filestorage/file/3435

  Document name: IM_LAN-WMBUS-SMK2
  Document version/status: Rev 1.4
  Latest change: 2022-08-23
  Page number: 6
  """
  alias Exmbus.Parser.Context
  alias Exmbus.Parser.Apl

  test "document example, Section 2.8" do
    # The full example is: 34443330670001000A1A7A070003052F2F047C03335344A081080002FD3A68018240FD3A380102FD46D00A8240FD46C50D02230000828040FD3A2D05027C035446237000027C034C41234501
    # We start from the APL, as that is what we care about in this example
    # and the document does not provide a demo key and encrypted bytes.
    apl_bytes =
      "047C03335344A081080002FD3A68018240FD3A380102FD46D00A8240FD46C50D02230000828040FD3A2D05027C035446237000027C034C41234501"
      |> Base.decode16!()

    {:continue, ctx} =
      Apl.FullFrame.parse(Context.new(bin: apl_bytes))

    assert [
             %Apl.DataRecord{
               header: %Apl.DataRecord.Header{
                 dib_bytes: <<4>>,
                 vib_bytes: <<124, 3, 51, 83, 68>>,
                 dib: %Apl.DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 32
                 },
                 vib: %Apl.DataRecord.ValueInformationBlock{
                   description: :plain_text_unit,
                   multiplier: nil,
                   unit: "DS3",
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 557_472
             },
             %Apl.DataRecord{
               header: %Apl.DataRecord.Header{
                 dib_bytes: <<2>>,
                 vib_bytes: <<253, 58>>,
                 dib: %Apl.DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %Apl.DataRecord.ValueInformationBlock{
                   description: :dimensionless,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :fd
                 },
                 coding: :type_b
               },
               data: 360
             },
             %Apl.DataRecord{
               header: %Apl.DataRecord.Header{
                 dib_bytes: <<130, 64>>,
                 vib_bytes: <<253, 58>>,
                 dib: %Apl.DataRecord.DataInformationBlock{
                   device: 1,
                   tariff: 0,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %Apl.DataRecord.ValueInformationBlock{
                   description: :dimensionless,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :fd
                 },
                 coding: :type_b
               },
               data: 312
             },
             %Apl.DataRecord{
               header: %Apl.DataRecord.Header{
                 dib_bytes: <<2>>,
                 vib_bytes: <<253, 70>>,
                 dib: %Apl.DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %Apl.DataRecord.ValueInformationBlock{
                   description: :volts,
                   multiplier: 0.001,
                   unit: "V",
                   extensions: [],
                   coding: nil,
                   table: :fd
                 },
                 coding: :type_b
               },
               data: 2768
             },
             %Apl.DataRecord{
               header: %Apl.DataRecord.Header{
                 dib_bytes: <<130, 64>>,
                 vib_bytes: <<253, 70>>,
                 dib: %Apl.DataRecord.DataInformationBlock{
                   device: 1,
                   tariff: 0,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %Apl.DataRecord.ValueInformationBlock{
                   description: :volts,
                   multiplier: 0.001,
                   unit: "V",
                   extensions: [],
                   coding: nil,
                   table: :fd
                 },
                 coding: :type_b
               },
               data: 3525
             },
             %Apl.DataRecord{
               header: %Apl.DataRecord.Header{
                 dib_bytes: <<2>>,
                 vib_bytes: "#",
                 dib: %Apl.DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %Apl.DataRecord.ValueInformationBlock{
                   description: :on_time,
                   multiplier: nil,
                   unit: "days",
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 0
             },
             %Apl.DataRecord{
               header: %Apl.DataRecord.Header{
                 dib_bytes: <<130, 128, 64>>,
                 vib_bytes: <<253, 58>>,
                 dib: %Apl.DataRecord.DataInformationBlock{
                   device: 2,
                   tariff: 0,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %Apl.DataRecord.ValueInformationBlock{
                   description: :dimensionless,
                   multiplier: nil,
                   unit: nil,
                   extensions: [],
                   coding: nil,
                   table: :fd
                 },
                 coding: :type_b
               },
               data: 1325
             },
             %Apl.DataRecord{
               header: %Apl.DataRecord.Header{
                 dib_bytes: <<2>>,
                 vib_bytes: <<124, 3, 84, 70, 35>>,
                 dib: %Apl.DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %Apl.DataRecord.ValueInformationBlock{
                   description: :plain_text_unit,
                   multiplier: nil,
                   unit: "#FT",
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 112
             },
             %Apl.DataRecord{
               header: %Apl.DataRecord.Header{
                 dib_bytes: <<2>>,
                 vib_bytes: <<124, 3, 76, 65, 35>>,
                 dib: %Apl.DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 16
                 },
                 vib: %Apl.DataRecord.ValueInformationBlock{
                   description: :plain_text_unit,
                   multiplier: nil,
                   unit: "#AL",
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 325
             }
           ] = ctx.apl.records
  end
end
