defmodule FullFrameTest do
  use ExUnit.Case, async: true

  alias Exmbus.Parser.Apl.DataRecord
  alias Exmbus.Parser.Apl
  alias Exmbus.Parser.Tpl
  alias Exmbus.Key
  alias Exmbus.Parser.Dll.Wmbus

  test "wmbus, unencrypted Table P.1 from en13757-3:2003" do
    datagram =
      Base.decode16!(
        "2E4493157856341233037A2A0000002F2F0C1427048502046D32371F1502FD1700002F2F2F2F2F2F2F2F2F2F2F2F2F"
      )

    assert {:ok, ctx, <<>>} = Exmbus.Parser.parse(datagram, length: true, crc: false)

    assert %{
             apl: %Apl.FullFrame{
               records: [
                 %Apl.DataRecord{
                   data: 2_850_427,
                   header: %Apl.DataRecord.Header{
                     dib: %{
                       data_type: :bcd,
                       device: 0,
                       storage: 0,
                       tariff: 0,
                       function_field: :instantaneous,
                       size: 32
                     },
                     vib: %{
                       description: :volume,
                       extensions: [],
                       multiplier: 0.01,
                       unit: "m^3"
                     },
                     coding: :type_a
                   }
                 },
                 %Apl.DataRecord{
                   data: ~N[2008-05-31 23:50:00],
                   header: %Apl.DataRecord.Header{
                     dib: %{
                       device: 0,
                       data_type: :int_or_bin,
                       size: 32,
                       storage: 0,
                       tariff: 0,
                       function_field: :instantaneous
                     },
                     vib: %{
                       coding: :type_f,
                       description: :naive_datetime,
                       extensions: [],
                       multiplier: nil,
                       unit: nil
                     }
                   }
                 },
                 %Apl.DataRecord{
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
                   header: %Apl.DataRecord.Header{
                     dib: %{
                       data_type: :int_or_bin,
                       size: 16,
                       device: 0,
                       storage: 0,
                       tariff: 0,
                       function_field: :instantaneous
                     },
                     vib: %{
                       description: :error_flags,
                       extensions: [],
                       multiplier: nil,
                       unit: nil
                     },
                     coding: :type_d
                   }
                 }
               ]
             },
             tpl: %Tpl{
               frame_type: :full_frame,
               header: %Tpl.Short{
                 access_no: 42,
                 configuration_field: %Tpl.ConfigurationField{mode: 0},
                 status: %Tpl.Status{
                   application_status: :no_error,
                   low_power: false,
                   manufacturer_status: 0b000,
                   permanent_error: false,
                   temporary_error: false
                 }
               }
             },
             dll: %Wmbus{
               manufacturer: "ELS",
               identification_no: 12_345_678,
               device: :gas,
               version: 51,
               control: :snd_nr
             }
           } = ctx
  end

  # we've not implemented frame format B with CRC checking yet.
  @tag :skip
  @tag :frame_format_b
  test "wmbus, encrypted: mode 5 Table P.1 from en13757-3:2003" do
    datagram =
      Base.decode16!(
        "2E4493157856341233037A2A0020055923C95AAA26D1B2E7493B013EC4A6F6D3529B520EDFF0EA6DEFC99D6D69EBF3"
      )

    key = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17>>

    # always return our one key.
    keyfn = fn _parsed, _opts ->
      {:ok, [key]}
    end

    assert {:ok, layers, <<>>} = Exmbus.Parser.parse(datagram, length: true, crc: true)
    assert [raw = %Apl.Raw{} | layers] = layers
    assert [_tpl = %Tpl{} | layers] = layers
    assert [_dll = %Wmbus{} | layers] = layers
    assert [] = layers

    assert %Apl.Raw{
             encrypted_bytes:
               <<89, 35, 201, 90, 170, 38, 209, 178, 231, 73, 59, 1, 62, 196, 166, 246, 211, 82,
                 155, 82, 14, 223, 240, 234, 109, 239, 201, 157, 109, 105, 235, 243>>,
             plain_bytes: ""
           } = raw

    assert {:ok, [%Apl.FullFrame{records: records} | _], ""} =
             Exmbus.Parser.parse(datagram, length: true, crc: true, key: Key.by_fn!(keyfn))

    assert [%DataRecord{}, %DataRecord{}, %DataRecord{}] = records
  end

  # we've not implemented frame format A with CRC checking yet.
  @tag :skip
  @tag :frame_format_a
  test "wmbus, encrypted: mode 5 Table F.2 from CEN/TR 17167:2018" do
    # without length and CRC:
    # datagram = Base.decode16!("4493444433221155087288776655934455080004100500DFE2A782146D1513581CD2F83F3904015B19")
    # with length and CRC:
    datagram =
      Base.decode16!(
        "294493444433221155086CB17288776655934455080004100500DFE227F9A782146D1513581CD2F83F3904015B196109"
      )

    key =
      <<0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E,
        0x0F>>

    keyfn = fn _parsed, _opts ->
      {:ok, [key]}
    end

    assert {:ok, %{apl: %Apl.FullFrame{records: records}}, ""} =
             Exmbus.Parser.parse(datagram, length: true, crc: true, key: Key.by_fn!(keyfn))

    assert [
             %DataRecord{
               data: 1234,
               header: %DataRecord.Header{
                 dib_bytes: "\v",
                 vib_bytes: "n",
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :bcd,
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
                 coding: :type_a
               }
             },
             %DataRecord{
               data: ~D[2007-04-30],
               header: %DataRecord.Header{
                 dib_bytes: "B",
                 vib_bytes: "l",
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
               }
             },
             %DataRecord{
               data: 23456,
               header: %DataRecord.Header{
                 dib_bytes: "K",
                 vib_bytes: "n",
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 1,
                   function_field: :instantaneous,
                   data_type: :bcd,
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
                 coding: :type_a
               }
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib_bytes: <<1>>,
                 vib_bytes: "[",
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 8
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :flow_temperature,
                   multiplier: 1,
                   unit: "°C",
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 25
             }
           ] = records
  end

  test "wmbus, encrypted: mode 5 Table F.2 from CEN/TR 17167:2018 but without length and CRC" do
    datagram =
      Base.decode16!(
        "4493444433221155087288776655934455080004100500DFE2A782146D1513581CD2F83F3904015B19"
      )

    key =
      <<0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E,
        0x0F>>

    keyfn = fn _parsed, _opts ->
      {:ok, [key]}
    end

    assert {:ok, %{apl: %Apl.FullFrame{records: records}}, ""} =
             Exmbus.Parser.parse(datagram, length: false, crc: false, key: Key.by_fn!(keyfn))

    assert [
             %DataRecord{
               data: 1234,
               header: %DataRecord.Header{
                 dib_bytes: "\v",
                 vib_bytes: "n",
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :bcd,
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
                 coding: :type_a
               }
             },
             %DataRecord{
               data: ~D[2007-04-30],
               header: %DataRecord.Header{
                 dib_bytes: "B",
                 vib_bytes: "l",
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
               }
             },
             %DataRecord{
               data: 23456,
               header: %DataRecord.Header{
                 dib_bytes: "K",
                 vib_bytes: "n",
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 1,
                   function_field: :instantaneous,
                   data_type: :bcd,
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
                 coding: :type_a
               }
             },
             %DataRecord{
               header: %DataRecord.Header{
                 dib_bytes: <<1>>,
                 vib_bytes: "[",
                 dib: %DataRecord.DataInformationBlock{
                   device: 0,
                   tariff: 0,
                   storage: 0,
                   function_field: :instantaneous,
                   data_type: :int_or_bin,
                   size: 8
                 },
                 vib: %DataRecord.ValueInformationBlock{
                   description: :flow_temperature,
                   multiplier: 1,
                   unit: "°C",
                   extensions: [],
                   coding: nil,
                   table: :main
                 },
                 coding: :type_b
               },
               data: 25
             }
           ] = records
  end
end
