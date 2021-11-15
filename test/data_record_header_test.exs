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
            assert {:ok, %DIB{}=dib, <<>>} = DIB.parse(bin, %{}, [])
            assert {:ok, ^bin} = DIB.unparse(%{}, [dib])
          end
      end
    end

  end


  describe "ValueInformationBlock" do

  end

end
