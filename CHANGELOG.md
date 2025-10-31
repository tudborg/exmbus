# Changelog for v0.x

## [development]

## [v0.3.3]

### Fixed

- Fixed bug in type A decoding that caused `0xF` digits to crash the parser in some cases.

## [v0.3.2]

### Added

- AFL MAC verification. Works for unfragmented AFLs.

## [v0.3.1]

### Added

- Authentication and Fragmentation layer (AFL) support added
  - fragmented messages not supported
  - Currently no MAC verification is done
- Security Profile 7 support added (ephemeral keys KDF)
- ELL CI `0x8E` support added

## [v0.3.0]

### Changed

- BREAKING: Making identification numbers **strings instead of integers**.
  This allows us to represent wildcard `F`s at any position.
- Parsing of the lower layers (DLL and TPL) have been made less brittle and will
  in more cases register errors in the context instead of raising an exception.
- BREAKING: Device value in DLL and TPL have been changed from an atom to a struct
  of type `Exmbus.Parser.Tpl.Device`

### Added

- Support for tariff related VIFE in 0xFD table `E011 00NN`.
- Support for VIFE in 0xFD: `E110 0110` State of parameter activation.
- Support for VIF `E001 1101` (Standard conform data content)
- Test for LAN-WMBUS-G2-LDS/LDP.
- Support for expansion of Compact Profile with Register Numbers (Orthogonal VIFE 0x1E)

## v0.2.0

Open-sourced
