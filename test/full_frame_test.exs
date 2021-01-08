defmodule FullFrameTest do
  use ExUnit.Case

  alias Exmbus.Message
  alias Exmbus.Apl.DataRecord
  alias Exmbus.Apl
  alias Exmbus.Apl.EncryptedApl
  alias Exmbus.Tpl
  alias Exmbus.Dll.Wmbus

  test "wmbus, unencrypted Table P.1 from en13757-3:2003" do
    datagram = Base.decode16!("2E4493157856341233037A2A0000002F2F0C1427048502046D32371F1502FD1700002F2F2F2F2F2F2F2F2F2F2F2F2F")
    assert {:ok, [
      %Apl{
        records: [
          %Exmbus.Apl.DataRecord{
            data: 2850427,
            header: %Exmbus.Apl.DataRecord.Header{
              coding: :bcd,
              data_type: :type_a,
              description: :volume,
              device: 0,
              extensions: [],
              function_field: :instantaneous,
              multiplier: 0.01,
              size: 32,
              storage: 0,
              tariff: 0,
              unit: "l",
            }
          },
          %Exmbus.Apl.DataRecord{
            data: ~N[2008-05-31 23:50:00],
            header: %Exmbus.Apl.DataRecord.Header{
              coding: :int_or_bin,
              data_type: :type_f,
              description: :naive_datetime,
              device: 0,
              extensions: [],
              function_field: :instantaneous,
              multiplier: nil,
              size: 32,
              storage: 0,
              tariff: 0,
              unit: nil,
            }
          },
          %Exmbus.Apl.DataRecord{
            data: [false, false, false, false, false, false, false, false,
                   false, false, false, false, false, false, false, false],
            header: %Exmbus.Apl.DataRecord.Header{
              coding: :int_or_bin,
              data_type: :type_d,
              description: :error_flags,
              device: 0,
              extensions: [],
              function_field: :instantaneous,
              multiplier: nil,
              size: 16,
              storage: 0,
              tariff: 0,
              unit: nil,
            }
          }
        ],
      },
      %Tpl{
        frame_type: :full_frame,
        header: %Tpl.Short{
          access_no: 42,
          configuration_field: %Tpl.ConfigurationField{mode: 0},
          status: %Tpl.Status{
            application_status: :no_error,
            low_power: false,
            manufacturer_status: 0b000,
            permanent_error: false,
            temporary_error: false,
          },
        },
      },
      %Wmbus{
        manufacturer: "ELS",
        identification_no: 12345678,
        device: 3,
        version: 51,
        control: :snd_nr,
      },
    ]} = Exmbus.parse_wmbus(datagram)
  end

  test "wmbus, encrypted: mode 5 Table P.1 from en13757-3:2003" do
    datagram = Base.decode16!("2E4493157856341233037A2A0020055923C95AAA26D1B2E7493B013EC4A6F6D3529B520EDFF0EA6DEFC99D6D69EBF3")
    key = <<1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,17>>

    # always return our one key.
    keyfn = fn (_parsed, _opts) ->
      {:ok, [key]}
    end

    assert {:ok, parsed=[
      %EncryptedApl{
        encrypted_bytes: <<89, 35, 201, 90, 170, 38, 209, 178, 231, 73, 59, 1, 62, 196, 166, 246,
                           211, 82, 155, 82, 14, 223, 240, 234, 109, 239, 201, 157, 109, 105, 235, 243>>,
        plain_bytes: <<>>,
        mode: {:mode, 5},
        iv: <<147, 21, 120, 86, 52, 18, 51, 3, 42, 42, 42, 42, 42, 42, 42, 42>>,
      },
      tpl=%Tpl{
        frame_type: :full_frame,
        header: %Tpl.Short{
          access_no: 42,
          configuration_field: %Tpl.ConfigurationField{mode: 5},
          status: %Tpl.Status{
            application_status: :no_error,
            low_power: false,
            manufacturer_status: 0b000,
            permanent_error: false,
            temporary_error: false,
          },
        },
      },
      dll=%Wmbus{
        manufacturer: "ELS",
        identification_no: 12345678,
        device: 3,
        version: 51,
        control: :snd_nr,
      },
    ]} = Exmbus.parse_wmbus(datagram)

    assert {:ok, plain_parsed=[
      %Apl{
        records: [
          %Exmbus.Apl.DataRecord{
            data: 2850427,
            header: %Exmbus.Apl.DataRecord.Header{
              coding: :bcd,
              data_type: :type_a,
              description: :volume,
              device: 0,
              extensions: [],
              function_field: :instantaneous,
              multiplier: 0.01,
              size: 32,
              storage: 0,
              tariff: 0,
              unit: "l",
            }
          },
          %Exmbus.Apl.DataRecord{
            data: ~N[2008-05-31 23:50:00],
            header: %Exmbus.Apl.DataRecord.Header{
              coding: :int_or_bin,
              data_type: :type_f,
              description: :naive_datetime,
              device: 0,
              extensions: [],
              function_field: :instantaneous,
              multiplier: nil,
              size: 32,
              storage: 0,
              tariff: 0,
              unit: nil,
            }
          },
          %Exmbus.Apl.DataRecord{
            data: [false, false, false, false, false, false, false, false,
                   false, false, false, false, false, false, false, false],
            header: %Exmbus.Apl.DataRecord.Header{
              coding: :int_or_bin,
              data_type: :type_d,
              description: :error_flags,
              device: 0,
              extensions: [],
              function_field: :instantaneous,
              multiplier: nil,
              size: 16,
              storage: 0,
              tariff: 0,
              unit: nil,
            }
          }
        ]
      },
      ^tpl,
      ^dll,
    ]} = Exmbus.decrypt(parsed, keyfn)

    assert {:ok, %Message{
        parsed: ^plain_parsed,
        manufacturer: "ELS",
        identification_no: 12345678,
        device: 3,
        version: 51,
    }} = Exmbus.to_message(datagram, keyfn: keyfn)
  end
end
