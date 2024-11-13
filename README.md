# Exmbus

Elixir M-Bus & Wireless M-Bus (wM-bus) parser library.


## Testing

`mix test`

## Benchmarks

Using Benchee, located in `benchmarks/`. Run with

```sh
mix run benchmarks/<name>.exs
```

## Profiling

Some profiling scripts are available under `profiling/`.

You can run then with e.g. eprof:

```sh
 mix profile.eprof profiling/oms_vol2_annex_n.exs
```

## TODO

- Implement examples from documentation as tests.
- Implement Authentication and fragmentation layer CI=90
  Example:
  `4474260730381029078C20EF900F002C2503A2F08F49703C7E1904BAF77ACF00300710E1AC2507238AF96DE27F1F5B28D2437F5D8A05E7ACE10AA95F84000F6E63856AD8870BE28AEED46ED706E81C3472FCBB`
- DLL CRC support. Currently CRC is hand-stripped from the specification examples.

