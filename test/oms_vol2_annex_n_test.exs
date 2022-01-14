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

  describe "N.5 Heat Cost Allocator" do
    # ACC-NR is not yet implemented
    @tag :skip
    test "N.5.2 wM-Bus Example with ACC-NR " do
      frame = "194793444433221155378C20758B8877665593445508FF040000" |> Base.decode16!()
      assert {:ok, ctx, <<>>} = Exmbus.parse(frame)
    end

    test "N.5.3 wM-Bus Example with partial encryption" do
      frame =
        "304493444433221155378C00757288776655934455080004100500DFE2A782146D1513581CD2F83F39040CFD1078563412"
        |> Base.decode16!()

      key = "000102030405060708090A0B0C0D0E0F" |> Base.decode16!()
      assert {:ok, ctx, <<>>} = Exmbus.parse(frame, key: key)

      assert [
               %Exmbus.Apl.FullFrame{
                 manufacturer_bytes: "",
                 records: [
                   %Exmbus.Apl.DataRecord{
                     data: 1234,
                     header: %Exmbus.Apl.DataRecord.Header{
                       coding: :type_a,
                       dib: %Exmbus.Apl.DataRecord.DataInformationBlock{
                         data_type: :bcd,
                         device: 0,
                         function_field: :instantaneous,
                         size: 24,
                         storage: 0,
                         tariff: 0
                       },
                       dib_bytes: "\v",
                       vib: %Exmbus.Apl.DataRecord.ValueInformationBlock{
                         coding: nil,
                         description: :units_for_hca,
                         extensions: [],
                         multiplier: nil,
                         table: :main,
                         unit: nil
                       },
                       vib_bytes: "n"
                     }
                   },
                   %Exmbus.Apl.DataRecord{
                     data: ~D[2007-04-30],
                     header: %Exmbus.Apl.DataRecord.Header{
                       coding: :type_g,
                       dib: %Exmbus.Apl.DataRecord.DataInformationBlock{
                         data_type: :int_or_bin,
                         device: 0,
                         function_field: :instantaneous,
                         size: 16,
                         storage: 1,
                         tariff: 0
                       },
                       dib_bytes: "B",
                       vib: %Exmbus.Apl.DataRecord.ValueInformationBlock{
                         coding: :type_g,
                         description: :date,
                         extensions: [],
                         multiplier: nil,
                         table: :main,
                         unit: nil
                       },
                       vib_bytes: "l"
                     }
                   },
                   %Exmbus.Apl.DataRecord{
                     data: 23456,
                     header: %Exmbus.Apl.DataRecord.Header{
                       coding: :type_a,
                       dib: %Exmbus.Apl.DataRecord.DataInformationBlock{
                         data_type: :bcd,
                         device: 0,
                         function_field: :instantaneous,
                         size: 24,
                         storage: 1,
                         tariff: 0
                       },
                       dib_bytes: "K",
                       vib: %Exmbus.Apl.DataRecord.ValueInformationBlock{
                         coding: nil,
                         description: :units_for_hca,
                         extensions: [],
                         multiplier: nil,
                         table: :main,
                         unit: nil
                       },
                       vib_bytes: "n"
                     }
                   },
                   %Exmbus.Apl.DataRecord{
                     data: 12_345_678,
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
                       dib_bytes: "\f",
                       vib: %Exmbus.Apl.DataRecord.ValueInformationBlock{
                         coding: :type_a,
                         description: :customer_location,
                         extensions: [],
                         multiplier: nil,
                         table: :fd,
                         unit: nil
                       },
                       vib_bytes: <<253, 16>>
                     }
                   }
                 ]
               },
               %Exmbus.Tpl{
                 frame_type: :full_frame,
                 header: %Exmbus.Tpl.Long{
                   access_no: 0,
                   configuration_field: %Exmbus.Tpl.ConfigurationField{
                     accessibility: false,
                     bidirectional: false,
                     blocks: 1,
                     content_of_message: 0,
                     hop_count: 0,
                     mode: 5,
                     repeater_access: 0,
                     syncrony: false
                   },
                   device: :heat_cost_allocator,
                   identification_no: 55_667_788,
                   manufacturer: "QDS",
                   status: %Exmbus.Tpl.Status{
                     application_status: :no_error,
                     low_power: true,
                     manufacturer_status: 0,
                     permanent_error: false,
                     temporary_error: false
                   },
                   version: 85
                 }
               },
               %Exmbus.Ell{
                 access_no: 117,
                 communication_control: %Exmbus.Ell.CommunicationControl{
                   accessibility: false,
                   bidirectional: false,
                   hop_count: false,
                   priority: false,
                   repeated_access: false,
                   response_delay: :slow_delay,
                   synchronized: false
                 },
                 session_number: nil
               },
               %Exmbus.Dll.Wmbus{
                 control: :snd_nr,
                 device: :radio_converter_meter_side,
                 identification_no: 11_223_344,
                 manufacturer: "QDS",
                 version: 85
               }
             ] = ctx
    end

    @tag :skip
    test "N.5.4 M-Bus Example with partial encryption" do
      # TODO: fill in this frame from the example (page 46)
      frame = "" |> Base.decode16!()
      key = "000102030405060708090A0B0C0D0E0F" |> Base.decode16!()
      assert {:ok, ctx, <<>>} = Exmbus.parse(frame, key: key)
    end
  end
end
