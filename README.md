# Exmbus

---

[![Build Status](https://github.com/tudborg/exmbus/actions/workflows/elixir.yml/badge.svg?branch=main)](https://github.com/tudborg/exmbus/actions/workflows/elixir.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/exmbus.svg)](https://hex.pm/packages/exmbus)
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/exmbus/)


Elixir M-Bus & Wireless M-Bus (wM-bus) parser library.

## Installation

The package can be installed by adding `exmbus` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:exmbus, "~> 0.2.0"}
  ]
end
```

## Features

- M-bus
- wM-bus
- TPL Encryption modes: 0, 5
- (partly) supports ELL (supports encryption modes: 0 (none), 1 (aes_128_ctr)
- Compact Frames and Format Frames
- Compact Profiles
- VIF extension tables 0xFD and 0xFB (with a few exceptions)

### Planned

- [ ] Transition the parser fully to handler + context based, and avoid raising on error but instead attach an error to the context. The APL layer in particular needs a lot of work here.
- [ ] Better API for encryption key storage.
- [ ] DLL CRC support.
- [ ] Split parsing and decoding into two steps. Currently the code parses the binary and decodes it in the same walk, but this causes errors when we can't decode an unsupported feature.

### Not Planned

- [ ] Authentication and Fragmentation layer CI=90


## Performance

It's fine.

You can run the benchmarks under `benchmarks/` to get an idea of the performance on the relevant hardware.

You should test on frames that matches your deployment scenario, but if you just want a rough estimate,
there is a benchmark using an example frame from OMS Vol2 Annex N:

```
mix run benchmarks/oms_vol2_annex_n.exs
```

Here are the results we've gathered so far for the "With input N.2.1. wM-Bus Meter with Security profile A" bench


| Hardware                  |        ips |       average | deviation |        median |        99th % |
|---------------------------|------------|---------------|-----------|---------------|---------------|
| Apple 12 core M3 Pro 36GB |   289.61 K |       3.45 μs |   ±63.73% |       3.13 μs |       7.21 μs |


## Examples

### Parse wM-Bus

This is an example from the OMS Vol2 Annex N - N.2.1. wM-Bus Meter with Security profile A

`Exmbus.parse!` will return an `Exmbus.Parser.Context` struct as the result.

```elixir
iex> "2E4493157856341233037A2A0020255923C95AAA26D1B2E7493B013EC4A6F6D3529B520EDFF0EA6DEFC99D6D69EBF3"
...> |> Base.decode16!()
...> |> Exmbus.parse!(key: Base.decode16!("0102030405060708090A0B0C0D0E0F11"))
%Exmbus.Parser.Context{
  bin: "",
  opts: %{
    length: false,
    key: <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17>>,
    crc: false
  },
  handlers: [],
  handler: &Exmbus.Parser.Apl.FullFrame.maybe_expand_compact_profiles/1,
  dll: %Exmbus.Parser.Dll.Wmbus{
    control: :snd_nr,
    manufacturer: "ELS",
    identification_no: 12345678,
    version: 51,
    device: :gas
  },
  ell: %Exmbus.Parser.Ell.None{},
  tpl: %Exmbus.Parser.Tpl{
    frame_type: :full_frame,
    header: %Exmbus.Parser.Tpl.Header.Short{
      access_no: 42,
      status: %Exmbus.Parser.Tpl.Status{
        manufacturer_status: 0,
        temporary_error: false,
        permanent_error: false,
        low_power: false,
        application_status: :no_error
      },
      configuration_field: %Exmbus.Parser.Tpl.ConfigurationField{
        hop_count: 0,
        repeater_access: 0,
        content_of_message: 0,
        mode: 5,
        syncrony: true,
        accessibility: false,
        bidirectional: false,
        blocks: 2
      }
    }
  },
  apl: %Exmbus.Parser.Apl.FullFrame{
    records: [
      %Exmbus.Parser.Apl.DataRecord{
        header: %Exmbus.Parser.Apl.DataRecord.Header{
          dib_bytes: "\f",
          vib_bytes: <<20>>,
          dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
            device: 0,
            tariff: 0,
            storage: 0,
            function_field: :instantaneous,
            data_type: :bcd,
            size: 32
          },
          vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
            description: :volume,
            multiplier: 0.01,
            unit: "m^3",
            extensions: [],
            coding: nil,
            table: :main
          },
          coding: :type_a
        },
        data: 2850427
      },
      %Exmbus.Parser.Apl.DataRecord{
        header: %Exmbus.Parser.Apl.DataRecord.Header{
          dib_bytes: <<4>>,
          vib_bytes: "m",
          dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
            device: 0,
            tariff: 0,
            storage: 0,
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
        data: ~N[2008-05-31 23:50:00]
      },
      %Exmbus.Parser.Apl.DataRecord{
        header: %Exmbus.Parser.Apl.DataRecord.Header{
          dib_bytes: <<2>>,
          vib_bytes: <<253, 23>>,
          dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
            device: 0,
            tariff: 0,
            storage: 0,
            function_field: :instantaneous,
            data_type: :int_or_bin,
            size: 16
          },
          vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
            description: :error_flags,
            multiplier: nil,
            unit: nil,
            extensions: [],
            coding: :type_d,
            table: :fd
          },
          coding: :type_d
        },
        data: [false, false, false, false, false, false, false, false, false,
         false, false, false, false, false, false, false]
      }
    ],
    manufacturer_bytes: ""
  },
  dib: nil,
  vib: nil,
  errors: [],
  warnings: []
}
```


## Testing

`mix test`

## Profiling

Some profiling scripts are available under `profiling/`.

You can run then with e.g. eprof:

```sh
 mix profile.eprof profiling/oms_vol2_annex_n.exs
```
