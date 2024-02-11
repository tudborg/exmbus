defmodule ValueInformationBlockTest do
  use ExUnit.Case, async: true

  alias Exmbus.Parser.Context
  alias Exmbus.Parser.Apl.DataRecord.DataInformationBlock, as: DIB
  alias Exmbus.Parser.Apl.DataRecord.ValueInformationBlock, as: VIB

  doctest Exmbus.Parser.Apl.DataRecord.ValueInformationBlock, import: true

  for i <- 0x00..0b01111010 do
    case <<i>> do
      <<0::1, 0b1101111::7>> = vib_bytes ->
        test "reserved: #{i}" do
          bin = unquote(vib_bytes)
          assert {:error, {:reserved, _}, <<>>} = VIB.parse(bin, %{}, [])
        end

      <<_::8>> = vib_bytes ->
        test "non-extended vib parse/unparse: #{Exmbus.Debug.u8_to_binary_str(i)}" do
          bin = unquote(vib_bytes)

          dib =
            case bin do
              <<_::1, 0b1101100::7>> ->
                %DIB{data_type: :int_or_bin, size: 16}

              _ ->
                %DIB{data_type: :int_or_bin, size: 32}
            end

          assert {:ok, vib, <<>>} = VIB.parse(bin, %{}, Context.new(dib: dib))
          assert {:ok, ^bin} = VIB.unparse(%{}, vib)
        end
    end
  end
end
