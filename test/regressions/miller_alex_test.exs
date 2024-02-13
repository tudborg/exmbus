defmodule Regressions.MillerAlexTest do
  use ExUnit.Case, async: true

  # used to cause: (RuntimeError) E001 0011 Inverse Compact Profile not supported
  test "wmbus, encrypted" do
    key = Base.decode16!("F8B24F12F9D113F680BEE765FDE67EC0")

    datagram =
      Base.decode16!(
        "6644496A3100015514377203926314496A00075000500598A78E0D71AA6358EEBD0B20BFDF99EDA2D22FA25314F3F1B84470898E495303923770BA8DDA97C964F0EA6CE24F5650C0A6CDF3DE37DE33FBFBEBACE4009BB0D8EBA2CBE80433FF131328206020B1BF"
      )

    assert {:ok, ctx, <<>>} = Exmbus.Parser.parse(datagram, length: true, crc: false, key: key)
  end

  # Used to cause:
  # ** (FunctionClauseError) no function clause matching in Exmbus.Parser.Apl.DataRecord.ValueInformationBlock.Vife.exts/4
  # NOTE: this frame is from a Lansen sensor, probably something like a CMa11.
  # It uses plain-text VIFs that are clearly incorrect according to the standard, so this frame is "invalid".
  # The problem is that header of the records are DIF, VIF, ASCII unit, VIFE, which is incorrect according to EN 13757-3:2018.
  # There is a counter example in section C.2, where the order with a VIFE is clearly defined.
  # However I suspect that this example has been added because the wording around where to place the ascii units is a bit unclear.
  # But logically, since the VIFE is a modifier to the VIF and always delimited by the extension bits, those should come first,
  # and the length-prefixed ASCII unit should come last, as the final part of the VIB.
  # (But in some mbus docs I could fine, it is said that the VIFE with extension bit 0 closes the VIB, so I totally get why someone would place the ASCII unit before it)
  @tag :skip
  test "mbus" do
    datagram =
      Base.decode16!(
        "684D4D680801720100000096150100180000000C785600000001FD1B0002FC0348522574440D22FC0348522574F10C12FC034852257463110265B409226586091265B70901720072650000B2016500001FB316"
      )

    assert {:ok, _ctx, <<>>} = Exmbus.Parser.parse(datagram, length: true, crc: false)
  end
end
