# this file serves as an entry point to run a profiler against.
defmodule Profile do
  def run() do
    frame =
      Base.decode16!(
        "2E4493157856341233037A2A0020255923C95AAA26D1B2E7493B013EC4A6F6D3529B520EDFF0EA6DEFC99D6D69EBF3"
      )

    key = "0102030405060708090A0B0C0D0E0F11" |> Base.decode16!()

    Enum.each(1..100_000, fn _ ->
      {:ok, %Exmbus.Parser.Context{}} = Exmbus.parse(frame, key: key)
    end)
  end
end

Profile.run()
