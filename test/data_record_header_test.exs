defmodule DataRecordHeaderTest do
  # NOTE:
  # Because of all of the dynamic programming, this module actually
  # adds significant execution time to the test suite.
  # Maybe we want to rewrite it at some point.
  use ExUnit.Case

  alias Exmbus.Apl.DataRecord.Header
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
            assert {:error, {:reserved_special_function, f}, <<>>} = DIB.parse(bin, %{}, [])
            assert is_integer(f)
          end

        # test special functions:
        <<special::4, 0b1111::4>> = dib_bytes ->
          test "special function: #{special}" do
            bin = unquote(dib_bytes)
            assert {:special_function, _, <<>>} = DIB.parse(bin, %{}, [])
          end

        # test non-extended dib
        <<0::1, storage::1, ff::2, df::4>> = dib_bytes ->
          test "non-extended dib parse/unparse storage=#{storage} function_field=#{ff} data_field=#{
                 df
               }" do
            bin = unquote(dib_bytes)
            assert {:ok, [%DIB{} = dib], <<>>} = DIB.parse(bin, %{}, [])
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

  describe "regressions" do
    test "parse/unparse header mismatch 2022-01-14" do
      # unparsing this yielded 01FA21 which ofc is wrong, it should be same as input
      orignal_drh = "01FF21" |> Base.decode16!()
      {:ok, [%Header{} = header], ""} = Header.parse(orignal_drh, %{}, [])

      assert %Exmbus.Apl.DataRecord.Header{
               coding: :type_b,
               dib: %Exmbus.Apl.DataRecord.DataInformationBlock{
                 data_type: :int_or_bin,
                 device: 0,
                 function_field: :instantaneous,
                 size: 8,
                 storage: 0,
                 tariff: 0
               },
               dib_bytes: <<1>>,
               vib: %Exmbus.Apl.DataRecord.ValueInformationBlock{
                 coding: nil,
                 description: :manufacturer_specific_encoding,
                 extensions: [manufacturer_specific_vife: 33],
                 multiplier: nil,
                 table: :main,
                 unit: nil
               },
               vib_bytes: <<255, 33>>
             } = header
      header = Map.drop(header, [:dib_bytes, :vib_bytes]) # be sure we don't "cheat" :)
      assert {:ok, <<0x01, 0xFF, 0x21>>, []} = Header.unparse(%{}, [header])
    end
  end
end
