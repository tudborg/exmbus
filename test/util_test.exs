defmodule UtilTest do
  @moduledoc """
  Tests the Exmbus.Util module.

  The Exmbus.Util module provides utilities for manipulating data using the Exmbus library.
  """

  use ExUnit.Case, async: true

  describe "rekey_ell/3" do
    setup do
      %{
        old_key: "0102030405060708090A0B0C0D0E0F10",
        new_key: "FFFEFDFCFBFAF9F8F7F6F5F4F3F2F1F0",
        old_payload: "08C67C819AAE99B4DE753AA136EF64917ED9D8B2E2D35840BDEA173B8FE14CCE3F1406B7CF",
        new_payload: "EACA1481EB0E11786A5103FE9244644833CB25A5F808E886925B1BA4F35F0A05277883718A",
        prefix: "442D2C1131342733028D20E9603A1020"
      }
      |> Map.new(fn {key, value} -> {key, Base.decode16!(value)} end)
    end

    test "basic example", ctx do
      assert {:ok, rekeyed_frame} =
               Exmbus.Util.rekey_ell(
                 ctx.prefix <> ctx.old_payload,
                 [length: false, key: ctx.old_key],
                 length: false,
                 key: ctx.new_key
               )

      # assert that the rekeyed payload matches the expected
      assert ctx.prefix <> ctx.new_payload == rekeyed_frame
    end

    test "swaps out identification number", ctx do
      assert {:ok, rekeyed_frame} =
               Exmbus.Util.rekey_ell(
                 ctx.prefix <> ctx.old_payload,
                 [length: false, identification_no: "00000001", key: ctx.old_key],
                 length: false,
                 key: ctx.new_key
               )

      {:ok, ctx} = Exmbus.parse(rekeyed_frame, key: ctx.new_key, length: false)
      assert ctx.dll.identification_no == "00000001"
    end

    # can add length
    test "Can add length", ctx do
      assert {:ok, rekeyed_frame} =
               Exmbus.Util.rekey_ell(
                 ctx.prefix <> ctx.old_payload,
                 [length: false, identification_no: "00000001", key: ctx.old_key],
                 length: true,
                 key: ctx.new_key
               )

      {:ok, ctx} = Exmbus.parse(rekeyed_frame, key: ctx.new_key, length: true)
      assert ctx.dll.identification_no == "00000001"
    end
  end
end
