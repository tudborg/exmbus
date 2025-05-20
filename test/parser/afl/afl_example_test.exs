defmodule Parser.Afl.AflExampleTest do
  @moduledoc """
  Example of frame using an AFL from CEN/TR 17167:2018 (page)

  It also uses encryption mode 7.

  The example is "F.3 Security mode 7 example" starting at page 34.
  """
  alias Exmbus.Parser.Ell.UnencryptedWithReceiver
  alias Exmbus.Parser.Apl.DataRecord

  use ExUnit.Case, async: true

  @absolute_meter_volume 28504.27
  @absolute_meter_volume_unit "m^3"

  @date_and_time ~N[2008-05-31 23:50:00]

  @master_key "000102030405060708090A0B0C0D0E0F"
  # @encrypted_session_key "ECCF39D475D730B8284FDFDC1995D52F"
  # @mac_session_key "C9CD19FF5A9AAD5A6BBDA13BD2C4C7AD"

  # from the example (CRC stripped)
  @message [
    # DLL
    "53082448443322110337",
    # ELL
    "8E80753A63665544330A31",
    # AFL
    "900F002C25B30A0000AF5D74DF73A600D9",
    # TPL
    "7278563412931533037500200710",
    # APL
    "9058475F4BC91DF878B80A1B0F98B629",
    # APL
    "024AAC727942BFC549233C0140829B93"
  ]

  test "parse F.3 Security mode 7 example" do
    frame = Base.decode16!(Enum.join(@message))
    key = Base.decode16!(@master_key)

    {:ok, ctx} = Exmbus.parse(frame, key: key)

    # we expect to be able to find the values in the description of the example
    assert is_list(ctx.apl.records)

    # meter:
    assert ctx.tpl.header.manufacturer == "ELS"
    assert ctx.tpl.header.identification_no == "12345678"
    assert ctx.tpl.header.version == 51
    # radio module:
    assert ctx.dll.manufacturer == "RAD"
    assert ctx.dll.identification_no == "11223344"
    # receiver (from the ELL):
    assert is_struct(ctx.ell, UnencryptedWithReceiver)
    assert ctx.ell.receiver.manufacturer == "XYZ"
    assert ctx.ell.receiver.identification_no == "33445566"

    assert [_ | _] = records = ctx.apl.records

    values = Enum.map(records, &%{value: DataRecord.value!(&1), unit: DataRecord.unit!(&1)})
    # check expected values present in records:
    assert %{unit: @absolute_meter_volume_unit, value: @absolute_meter_volume} in values
    assert %{unit: nil, value: @date_and_time} in values
    # errors flags, all 0:
    assert %{unit: nil, value: for(_ <- 1..16, do: false)} in values
  end
end
