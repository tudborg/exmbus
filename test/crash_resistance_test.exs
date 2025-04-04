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
end
