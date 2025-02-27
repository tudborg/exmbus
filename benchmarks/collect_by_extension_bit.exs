defmodule Bench do
  def collect_by_extension_bit(<<0::1, _::7, _::binary>> = bin) do
    <<block::binary-size(1), rest::binary>> = bin
    {:ok, block, rest}
  end

  def collect_by_extension_bit(<<1::1, _::7, 0::1, _::7, _::binary>> = bin) do
    <<block::binary-size(2), rest::binary>> = bin
    {:ok, block, rest}
  end

  def collect_by_extension_bit(<<1::1, _::7, 1::1, _::7, 0::1, _::7, _::binary>> = bin) do
    <<block::binary-size(3), rest::binary>> = bin
    {:ok, block, rest}
  end

  def collect_by_extension_bit(
        <<1::1, _::7, 1::1, _::7, 0::1, _::7, 0::1, _::7, _::binary>> = bin
      ) do
    <<block::binary-size(4), rest::binary>> = bin
    {:ok, block, rest}
  end

  def collect_by_extension_bit(bin) do
    generic_collect_by_extension_bit(bin, 4)
  end

  defp generic_collect_by_extension_bit(bin, byte_len) do
    case bin do
      <<_::binary-size(byte_len), 0::1, _::7, _::binary>> ->
        <<block::binary-size(byte_len + 1), rest::binary>> = bin
        {:ok, block, rest}

      <<_::binary-size(byte_len), 1::1, _::7, _::binary>> ->
        generic_collect_by_extension_bit(bin, byte_len + 1)
    end
  end
end

iterations = 1000

Benchee.run(
  %{
    "current" => fn input ->
      Enum.each(1..iterations, fn _ ->
        Exmbus.Parser.Binary.collect_by_extension_bit(input)
      end)
    end,
    "proposed" => fn input ->
      Enum.each(1..iterations, fn _ ->
        Bench.collect_by_extension_bit(input)
      end)
    end
  },
  formatters: [
    {Benchee.Formatters.HTML, file: "benchmarks/results/collect_by_extension_bit.html"},
    Benchee.Formatters.Console
  ],
  time: 3,
  warmup: 1,
  inputs: %{
    "Realistic" => <<1::1, 0::7, 1::1, 0::7, 0x00, 0x00, 1::1, 0::7, 1::1, 0::7, 0x00, 0x00>>
  }
)
