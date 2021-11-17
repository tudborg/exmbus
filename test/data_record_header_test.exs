defmodule DataRecordHeaderTest do
  use ExUnit.Case

  alias Exmbus.Apl.DataRecord.DataInformationBlock, as: DIB
  alias Exmbus.Apl.DataRecord.ValueInformationBlock, as: VIB

  doctest Exmbus.Apl.DataRecord.Header, import: true
  doctest Exmbus.Apl.DataRecord.DataInformationBlock, import: true
  doctest Exmbus.Apl.DataRecord.ValueInformationBlock, import: true


  describe "DataInformationBlock" do

    # Test all non-extended dibs
    # We use some meta-programming here to programatically set up a test
    # for all DIBs.
    # Individual tests should not go inside this `for` block
    for i <- 0b00000000..0b01111111 do
      case <<i>> do
        <<reserved>> = dib_bytes when reserved in [0x3F, 0x4F, 0x5F, 0x6F] ->
          test "reserved: #{reserved}" do
            bin = unquote(dib_bytes)
            assert {:error, {:reserved, _}} = DIB.parse(bin, %{}, [])
          end
        # test special functions:
        <<special::4, 0b1111::4>> = dib_bytes ->
          test "special function: #{special}" do
            bin = unquote(dib_bytes)
            assert {:special_function, _, <<>>} = DIB.parse(bin, %{}, [])
          end
        # test non-extended dib
        <<0::1, storage::1, ff::2, df::4>> = dib_bytes ->
          test "non-extended dib parse/unparse storage=#{storage} function_field=#{ff} data_field=#{df}" do
            bin = unquote(dib_bytes)
            assert {:ok, [%DIB{}=dib], <<>>} = DIB.parse(bin, %{}, [])
            assert {:ok, ^bin, []} = DIB.unparse(%{}, [dib])
          end
      end
    end
  end

  describe "ValueInformationBlock" do
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
            assert {:ok, ctx, <<>>} = VIB.parse(bin, %{}, [dib])
            assert {:ok, ^bin, [^dib]} = VIB.unparse(%{}, ctx)
          end
      end
    end
  end

end
