defmodule CrashResistanceTest do
  @moduledoc """
  Test that the parser can handle unexpected frames without crashing.
  """
  alias Exmbus.Parser.Context
  alias Exmbus.Parser.Afl
  alias Exmbus.Parser.Afl.FragmentationControlField

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

  test "Unexpected return from handler" do
    # ensure that a handler misbehaving doesn't crash the parser, instead it adds an error to the context and halts
    handler = fn _ctx -> {:error, :reason} end
    assert {:error, ctx} = Exmbus.parse(<<>>, Context.new(handlers: [handler]))
    assert ctx.errors == [{handler, {:unexpected_return, {:error, :reason}}}]
  end

  test "unsupported wmbus dll control field is a parse error" do
    handler = &Exmbus.Parser.Dll.parse/1

    frame =
      Base.decode16!(
        "2E4093157856341233037A2A0020255923C95AAA26D1B2E7493B013EC4A6F6D3529B520EDFF0EA6DEFC99D6D69EBF3"
      )

    assert {:error, %{errors: [{^handler, {:not_implemented, :snd_nke}}]}} =
             Exmbus.parse(frame, key: [])
  end

  test "unsupported mbus dll control field is a parse error" do
    handler = &Exmbus.Parser.Dll.parse/1
    frame = <<0x68, 3, 3, 0x68, 0x40, 0x00, 0x78, 0xB8, 0x16>>

    assert {:error, %{errors: [{^handler, {:not_implemented, :snd_nke}}]}} =
             Exmbus.parse(frame)
  end

  test "truncated tpl headers are parse errors" do
    handler = &Exmbus.Parser.Tpl.parse/1
    ctx = Context.new(handlers: [handler])

    assert {:error, %{errors: [{^handler, {:invalid_tpl_header, :short}}]}} =
             Exmbus.parse(<<0x7A>>, ctx)
  end

  test "fragmented afl is a parse error" do
    handler = &Exmbus.Parser.Tpl.parse/1
    fcl = %FragmentationControlField{fragment_id: 1}
    ctx = Context.new(handlers: [handler], afl: %Afl{fcl: fcl})

    assert {:error, %{errors: [{^handler, {:not_implemented, :fragmented_afl}}]}} =
             Exmbus.parse(<<0x7A>>, ctx)
  end

  test "truncated afl is a parse error" do
    handler = &Exmbus.Parser.Afl.parse/1
    ctx = Context.new(handlers: [handler])

    assert {:error, %{errors: [{^handler, {:invalid_afl, :truncated}}]}} =
             Exmbus.parse(<<0x90, 1, 0>>, ctx)
  end

  test "unsupported ell variants are parse errors" do
    handler = &Exmbus.Parser.Ell.parse/1
    ctx = Context.new(handlers: [handler])

    assert {:error, %{errors: [{^handler, {:not_implemented, :ell_v}}]}} =
             Exmbus.parse(<<0x86>>, ctx)
  end
end
