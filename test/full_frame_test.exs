defmodule FullFrameTest do
  use ExUnit.Case

  alias Exmbus.Dll.Wmbus

  test "wmbus, unencrypted Table P.1 from en13757-3:2003" do
    datagram = Base.decode16!("2E4493157856341233037A2A0000002F2F0C1427048502046D32371F1502FD1700002F2F2F2F2F2F2F2F2F2F2F2F2F")

    {:ok, dll=%Wmbus{}} = Exmbus.decode_wmbus(datagram)
  end

  test "wmbus, encrypted: mode 5 Table P.1 from en13757-3:2003" do
    datagram = Base.decode16!("2E4493157856341233037A2A0020055923C95AAA26D1B2E7493B013EC4A6F6D3529B520EDFF0EA6DEFC99D6D69EBF3")
    key = <<1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,17>>
    keyfn = fn(mode, args) ->
      {:ok, [key]}
    end
    {:ok, dll=%Wmbus{}} = Exmbus.decode_wmbus(datagram, keyfn: keyfn)
  end
end
