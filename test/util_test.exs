defmodule UtilTest do
  @moduledoc """
  Tests the Exmbus.Util module.

  The Exmbus.Util module provides utilities for manipulating data using the Exmbus library.
  """

  use ExUnit.Case, async: true

  test "rekey_ell/4" do
    old_key = "0102030405060708090A0B0C0D0E0F10" |> Base.decode16!()
    new_key = "FFFEFDFCFBFAF9F8F7F6F5F4F3F2F1F0" |> Base.decode16!()

    prefix = "442D2C1131342733028D20E9603A1020" |> Base.decode16!()

    old_payload =
      "08C67C819AAE99B4DE753AA136EF64917ED9D8B2E2D35840BDEA173B8FE14CCE3F1406B7CF"
      |> Base.decode16!()

    new_payload =
      "EACA1481EB0E11786A5103FE9244644833CB25A5F808E886925B1BA4F35F0A05277883718A"
      |> Base.decode16!()

    assert {:ok, rekeyed_frame} =
             Exmbus.Util.rekey_ell(prefix <> old_payload, [length: false], old_key, new_key)

    # assert that the rekeyed payload matches the expected
    assert prefix <> new_payload == rekeyed_frame
  end
end
