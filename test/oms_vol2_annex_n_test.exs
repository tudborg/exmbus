defmodule OMSVol2AnnexNTest do
  # OMS Spec Vol2 Annex N D103 2020-10-22
  use ExUnit.Case

  alias Exmbus.Apl.FullFrame
  alias Exmbus.Apl.DataRecord
  alias Exmbus.Tpl
  alias Exmbus.Tpl.Short
  alias Exmbus.Tpl.Status
  alias Exmbus.Tpl.ConfigurationField
  alias Exmbus.Dll.Wmbus
  alias Exmbus.Dll.Mbus

  describe "N.2. Gas Meter" do
    test "N.2.1. wM-Bus Meter with Security profile A" do
      aes_key = "0102030405060708090A0B0C0D0E0F11" |> Base.decode16!()
      # DLL
      # TPL
      # APL #1
      # APL #2
      bytes =
        ("449315785634123303" <>
           "7A2A0020255923" <>
           "C95AAA26D1B2E7493B013EC4A6F6" <>
           "D3529B520EDFF0EA6DEFC99D6D69EBF3")
        |> Base.decode16!()

      assert {:ok, ctx, <<>>} = Wmbus.parse(bytes, %{length: false, key: aes_key}, [])

      assert [
               %FullFrame{
                 manufacturer_bytes: <<>>,
                 records: [
                   %DataRecord{} = dr1,
                   %DataRecord{} = dr2,
                   %DataRecord{} = dr3
                 ]
               },
               %Tpl{
                 frame_type: :full_frame,
                 header: %Short{
                   access_no: 0x2A,
                   status: %Status{
                     application_status: :no_error,
                     low_power: false,
                     permanent_error: false,
                     temporary_error: false,
                     manufacturer_status: 0b000
                   },
                   configuration_field: %ConfigurationField{
                     accessibility: false,
                     bidirectional: false,
                     blocks: 2,
                     content_of_message: 0,
                     hop_count: 0,
                     mode: 5,
                     repeater_access: 0,
                     syncrony: true
                   }
                 }
               },
               %Wmbus{
                 manufacturer: "ELS",
                 identification_no: 12_345_678,
                 device: :gas,
                 version: 51,
                 control: :snd_nr
               }
             ] = ctx

      assert %DataRecord{header: %{dib: %{storage: 0}}} = dr1
      assert %DataRecord{header: %{dib: %{storage: 0}}} = dr2
      assert %DataRecord{header: %{dib: %{storage: 0}}} = dr3

      # the value
      assert {:ok, 28504.27} == DataRecord.value(dr1)
      assert {:ok, "m^3"} == DataRecord.unit(dr1)

      # the time
      assert {:ok, ~N[2008-05-31 23:50:00]} == DataRecord.value(dr2)
      assert {:ok, nil} == DataRecord.unit(dr2)

      # the error flags
      assert {:ok,
              [
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
                false,
                false,
                false,
                false
              ]} == DataRecord.value(dr3)

      assert {:ok, nil} == DataRecord.unit(dr3)
    end

    test "N.2.2. M-Bus Meter with no encryption" do
      # DLL
      # TPL
      # APL #1
      # DLL
      bytes =
        ("6820206808FD" <>
           "7278563412931533032A000000" <>
           "0C1427048502046D32371F1502FD170000" <>
           "8916")
        |> Base.decode16!()

      assert {:ok, ctx, <<>>} = Mbus.parse(bytes, %{}, [])

      assert [
               %Exmbus.Apl.FullFrame{
                 manufacturer_bytes: "",
                 records: [
                   %Exmbus.Apl.DataRecord{
                     data: 2_850_427,
                     header: %Exmbus.Apl.DataRecord.Header{
                       coding: :type_a,
                       dib: %Exmbus.Apl.DataRecord.DataInformationBlock{
                         data_type: :bcd,
                         device: 0,
                         function_field: :instantaneous,
                         size: 32,
                         storage: 0,
                         tariff: 0
                       },
                       vib: %Exmbus.Apl.DataRecord.ValueInformationBlock{
                         coding: nil,
                         description: :volume,
                         extensions: [],
                         multiplier: 0.01,
                         table: :main,
                         unit: "m^3"
                       }
                     }
                   },
                   %Exmbus.Apl.DataRecord{
                     data: ~N[2008-05-31 23:50:00],
                     header: %Exmbus.Apl.DataRecord.Header{
                       coding: :type_f,
                       dib: %Exmbus.Apl.DataRecord.DataInformationBlock{
                         data_type: :int_or_bin,
                         device: 0,
                         function_field: :instantaneous,
                         size: 32,
                         storage: 0,
                         tariff: 0
                       },
                       vib: %Exmbus.Apl.DataRecord.ValueInformationBlock{
                         coding: :type_f,
                         description: :naive_datetime,
                         extensions: [],
                         multiplier: nil,
                         table: :main,
                         unit: nil
                       }
                     }
                   },
                   %Exmbus.Apl.DataRecord{
                     data: [
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
                       false,
                       false,
                       false,
                       false
                     ],
                     header: %Exmbus.Apl.DataRecord.Header{
                       coding: :type_d,
                       dib: %Exmbus.Apl.DataRecord.DataInformationBlock{
                         data_type: :int_or_bin,
                         device: 0,
                         function_field: :instantaneous,
                         size: 16,
                         storage: 0,
                         tariff: 0
                       },
                       vib: %Exmbus.Apl.DataRecord.ValueInformationBlock{
                         coding: :type_d,
                         description: :error_flags,
                         extensions: [],
                         multiplier: nil,
                         table: :fd,
                         unit: nil
                       }
                     }
                   }
                 ]
               },
               %Exmbus.Tpl{
                 frame_type: :full_frame,
                 header: %Exmbus.Tpl.Long{
                   access_no: 42,
                   configuration_field: %Exmbus.Tpl.ConfigurationField{
                     accessibility: false,
                     bidirectional: false,
                     blocks: nil,
                     content_of_message: 0,
                     hop_count: 0,
                     mode: 0,
                     repeater_access: 0,
                     syncrony: false
                   },
                   device: :gas,
                   identification_no: 12_345_678,
                   manufacturer: "ELS",
                   status: %Exmbus.Tpl.Status{
                     application_status: :no_error,
                     low_power: false,
                     manufacturer_status: 0,
                     permanent_error: false,
                     temporary_error: false
                   },
                   version: 51
                 }
               },
               %Mbus{
                 control: :rsp_ud,
                 # secondary addressing
                 address: 0xFD
               }
             ] = ctx
    end
  end
end
