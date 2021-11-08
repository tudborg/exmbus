defmodule FullFrameTest do
  use ExUnit.Case

  alias Exmbus.Message
  alias Exmbus.Apl.DataRecord
  alias Exmbus.Apl
  alias Exmbus.Tpl
  alias Exmbus.Key
  alias Exmbus.Dll.Wmbus

  test "wmbus, unencrypted Table P.1 from en13757-3:2003" do
    datagram = Base.decode16!("2E4493157856341233037A2A0000002F2F0C1427048502046D32371F1502FD1700002F2F2F2F2F2F2F2F2F2F2F2F2F")
    assert {:ok, %Message{}=message} = Exmbus.parse(datagram, keep_layers: true)
    assert [
      %Apl{
        records: [
          %Exmbus.Apl.DataRecord{
            data: 2850427,
            header: %Exmbus.Apl.DataRecord.Header{
              coding: :bcd, data_type: :type_a,
              description: :volume, device: 0, extensions: [],
              function_field: :instantaneous,
              multiplier: 0.01, size: 32, storage: 0, tariff: 0, unit: "l",
            }
          },
          %Exmbus.Apl.DataRecord{
            data: ~N[2008-05-31 23:50:00],
            header: %Exmbus.Apl.DataRecord.Header{
              coding: :int_or_bin, data_type: :type_f,
              description: :naive_datetime, device: 0, extensions: [],
              function_field: :instantaneous,
              multiplier: nil, size: 32, storage: 0, tariff: 0, unit: nil,
            }
          },
          %Exmbus.Apl.DataRecord{
            data: [false, false, false, false, false, false, false, false,
                   false, false, false, false, false, false, false, false],
            header: %Exmbus.Apl.DataRecord.Header{
              coding: :int_or_bin, data_type: :type_d,
              description: :error_flags, device: 0, extensions: [],
              function_field: :instantaneous,
              multiplier: nil, size: 16, storage: 0, tariff: 0, unit: nil,
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
            application_status: :no_error, low_power: false, manufacturer_status: 0b000,
            permanent_error: false, temporary_error: false,
          },
        },
      },
      %Wmbus{manufacturer: "ELS", identification_no: 12345678, device: :gas, version: 51, control: :snd_nr},
    ] = message.layers
  end

  test "wmbus, encrypted: mode 5 Table P.1 from en13757-3:2003" do
    datagram = Base.decode16!("2E4493157856341233037A2A0020055923C95AAA26D1B2E7493B013EC4A6F6D3529B520EDFF0EA6DEFC99D6D69EBF3")
    key = <<1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,17>>

    # always return our one key.
    keyfn = fn (_parsed, _opts) ->
      {:ok, [key]}
    end

    assert {:ok, %Message{layers: layers, records: :encrypted}} = Exmbus.parse(datagram)
    assert [eapl=%Apl.Encrypted{} | layers] = layers
    assert [_tpl=%Tpl{} | layers] = layers
    assert [_dll=%Wmbus{} | layers] = layers
    assert [] = layers

    assert %Apl.Encrypted{
      encrypted_bytes: <<89, 35, 201, 90, 170, 38, 209, 178, 231, 73, 59, 1, 62, 196, 166, 246, 211, 82, 155, 82, 14, 223, 240, 234, 109, 239, 201, 157, 109, 105, 235, 243>>,
      iv: <<147, 21, 120, 86, 52, 18, 51, 3, 42, 42, 42, 42, 42, 42, 42, 42>>,
      mode: {:mode, 5},
      plain_bytes: ""
    } = eapl

    assert {:ok, %Message{layers: nil, records: records}} = Exmbus.parse(datagram, key: Key.by_fn(keyfn))
    assert [%DataRecord{}, %DataRecord{}, %DataRecord{}] = records
  end

  test "wmbus, encrypted: mode 5 Table F.2 from CEN/TR 17167:2018" do
    datagram = Base.decode16!("294493444433221155087288776655934455080004100500DFE2A782146D1513581CD2F83F3904015B19")
    key = <<0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F>>
    keyfn = fn (_parsed, _opts) ->
      {:ok, [key]}
    end
    assert %{
      device: :heat_cost_allocator,
      manufacturer: "QDS",
      identification_no: 55667788,
      version: 85,
      records: [
        %{function_field: :instantaneous, device: 0, tariff: 0, storage: 0, description: :units_for_hca,    unit: nil,  value: 1234},
        %{function_field: :instantaneous, device: 0, tariff: 0, storage: 1, description: :date,             unit: nil,  value: ~D[2007-04-30]},
        %{function_field: :instantaneous, device: 0, tariff: 0, storage: 1, description: :units_for_hca,    unit: nil,  value: 23456},
        %{function_field: :instantaneous, device: 0, tariff: 0, storage: 0, description: :flow_temperature, unit: "°C", value: 25},
      ],
    } = Exmbus.simplified!(datagram, key: Key.by_fn(keyfn))
  end

end
