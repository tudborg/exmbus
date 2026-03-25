defmodule Compatibility.LAN_WMBUS_G2_LDS_LDSTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Tests for the LAN-WMBUS-G2-LDS/LDP leakage detector device.
  At time of writing, document stored at https://www.lansensystems.com/media/1215/g2_lds_data_format_v8_0.pdf
  product page: https://www.lansensystems.com/assortment/sensors/protection/lan-wmbus-g2-ldp-kit-1/
  """
  alias Exmbus.Parser.Apl.DataRecord
  alias Exmbus.Parser.Context

  test "document example, Section 2.8" do
    frame =
      "443330670001000B1E7A070003002F2F02FD1B000002FD971D000002FD3AFF038240FD3AFF03"
      |> Base.decode16!()

    assert {:ok, ctx} = Exmbus.parse(frame, length: false)

    assert %Context{
             bin: <<>>,
             dll: %{manufacturer: "LAS", identification_no: "00010067", version: 11},
             tpl: %{header: %{access_no: 7}},
             apl: %{records: records, manufacturer_bytes: <<>>}
           } = ctx

    assert [
             %DataRecord{header: %{dib_bytes: <<0x02>>, vib_bytes: <<0xFD, 0x1B>>}} = a,
             %DataRecord{header: %{dib_bytes: <<0x02>>, vib_bytes: <<0xFD, 0x97, 0x1D>>}} = b,
             %DataRecord{header: %{dib_bytes: <<0x02>>, vib_bytes: <<0xFD, 0x3A>>}} = c,
             %DataRecord{header: %{dib_bytes: <<0x82, 0x40>>, vib_bytes: <<0xFD, 0x3A>>}} = d
           ] = records

    assert %DataRecord{header: %{vib: %{description: :digital_input}}, data: 0x00} = a

    assert %DataRecord{
             header: %{vib: %{description: :error_flags, extensions: [:standard_conform]}},
             data: flags
           } =
             b

    assert is_list(flags) and length(flags) == 16

    assert %DataRecord{
             header: %{dib: %{storage: 0, device: 0}, vib: %{description: :dimensionless}},
             data: 0x3FF
           } =
             c

    assert %DataRecord{
             header: %{dib: %{storage: 0, device: 1}, vib: %{description: :dimensionless}},
             data: 0x3FF
           } = d
  end
end
