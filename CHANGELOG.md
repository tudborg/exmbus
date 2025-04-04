# Changelog for v0.x

## [Unreleased]

### Changed

- Making identification numbers **strings instead of integers**.
  This allows us to represent wildcard `F`s at any position.
- Parsing of the lower layers (DLL and TPL) have been made less brittle and will
  in more cases register errors in the context instead of raising an exception.

### Added

- Support for VIFE `E001 1101` (Standard conform data content)
- Test for LAN-WMBUS-G2-LDS/LDP
- Support for expansion of Compact Profile with Register Numbers (Orthogonal VIFE 0x1E)

## v0.2.0

Open-sourced
