defmodule CrashResistanceTest do
  @moduledoc """
  Test that the parser can handle unexpected frames without crashing.
  """

  use ExUnit.Case, async: true

  test "Frame with invalid identification_no and manufacturer specific CI" do
    frame = Base.decode16!("1944304C716F55212404A1031A0013BA03D5FEC7CECF82D14B7E")
    {:error, ctx} = Exmbus.parse(frame)

    assert ctx.errors == [
             {&Exmbus.Parser.Tpl.parse/1, {:unexpected_ci, {:apl, :manufacturer_specific}}}
           ]
  end

  @example_frame ("2E449315785634123303" <>
                    "7A2A0020255923" <>
                    "C95AAA26D1B2E7493B013EC4A6F6" <>
                    "D3529B520EDFF0EA6DEFC99D6D69EBF3")
                 |> Base.decode16!()

  describe "invalid keys" do
    test "bad length" do
      assert {:error, %{errors: [_]}} = Exmbus.parse(@example_frame, key: "")
      assert {:error, %{errors: [_]}} = Exmbus.parse(@example_frame, key: "1")
    end

    test "bad key among good keys" do
      aes_key = "0102030405060708090A0B0C0D0E0F11" |> Base.decode16!()
      bad_key = "0102030405060708090A0B0C0D0E0F12" |> Base.decode16!()

      assert {:ok, %{}} = Exmbus.parse(@example_frame, key: [bad_key, aes_key])
    end
  end
end
