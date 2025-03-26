defmodule Regressions.SonAplCompactProfileWithRegisterNumbersTest do
  use ExUnit.Case, async: true
  alias Exmbus.Parser.Apl.DataRecord
  alias Exmbus.Parser.Context

  test "SON water meter frame containing compact profile with register numbers" do
    frame =
      "0C1381420200426C1F3C4C135559000082046CFF2C8C0413000000008D04931E3A3CFE0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000555900002723010037840100"
      |> Base.decode16!()

    handlers =
      Enum.drop_while(Context.default_handlers(), fn handler ->
        handler != (&Exmbus.Parser.Apl.parse/1)
      end)

    ctx = Context.new(handlers: handlers, tpl: %{frame_type: :full_frame})
    assert {:ok, %{apl: %{records: records}}} = Exmbus.parse(frame, ctx)

    assert [
             %DataRecord{header: %{dib: %{device: 0, storage: 0, tariff: 0}}},
             %DataRecord{header: %{dib: %{device: 0, storage: 1, tariff: 0}}},
             %DataRecord{header: %{dib: %{device: 0, storage: 1, tariff: 0}}},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{},
             %DataRecord{}
           ] = records
  end
end
