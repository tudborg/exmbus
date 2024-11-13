#
# Benchmarks parsing of frames from the OMS Vol2 Annex N specification
#

defmodule Bench do
  def parse(%{frame: frame, key: key}) do
    Exmbus.parse(frame, key: key)
  end
end

Benchee.run(
  %{"Exmbus.parse" => &Bench.parse/1},
  formatters: [
    {Benchee.Formatters.HTML, file: "benchmarks/results/oms_vol2_annex_n.html"},
    {Benchee.Formatters.Console, extended_statistics: true}
  ],
  time: 2,
  memory_time: 2,
  warmup: 2,
  inputs: %{
    "N.2.1. wM-Bus Meter with Security profile A" => %{
      frame:
        Base.decode16!(
          "4493157856341233037A2A0020255923C95AAA26D1B2E7493B013EC4A6F6D3529B520EDFF0EA6DEFC99D6D69EBF3"
        ),
      key: "0102030405060708090A0B0C0D0E0F11" |> Base.decode16!()
    },
    "N.2.2. M-Bus Meter with no encryption" => %{
      frame:
        Base.decode16!(
          "6820206808FD7278563412931533032A0000000C1427048502046D32371F1502FD1700008916"
        ),
      key: nil
    },
    "N.5.3 wM-Bus Example with partial encryption" => %{
      frame:
        Base.decode16!(
          "304493444433221155378C00757288776655934455080004100500DFE2A782146D1513581CD2F83F39040CFD1078563412"
        ),
      key: "000102030405060708090A0B0C0D0E0F" |> Base.decode16!()
    }
  }
)
