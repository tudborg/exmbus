defmodule Parser.DataTypeTest do
  use ExUnit.Case, async: true

  alias Exmbus.Parser.DataType.PeriodicDate
  alias Exmbus.Parser.DataType

  doctest Exmbus.Parser.DataType, import: true

  # lvar
  # type_a
  # type_b
  # type_c
  # type_d
  # type_f
  # type_g
  # type_h
  # type_i
  # type_j
  # type_k
  # type_l
  # type_m

  # Type A - BCD
  for {bit_size, value} <- [
        {8, 12},
        {16, 1234},
        {24, 123_456},
        {32, 12_345_678},
        {48, 1_234_567_890}
      ] do
    test "encode_type_a/2 and decode_type_a/2 for bit size #{bit_size}" do
      bit_size = unquote(bit_size)
      byte_size = div(bit_size, 8)
      value = unquote(value)
      {:ok, <<data::binary-size(byte_size)>>} = DataType.encode_type_a(value, bit_size)
      {:ok, ^value, <<>>} = DataType.decode_type_a(data, bit_size)
    end
  end

  # Type B - Signed integer
  for {bit_size, value} <- [
        {8, 12},
        {16, -1234},
        {24, 123_456},
        {32, -12_345_678},
        {48, 1_234_567_890},
        {64, 1_234_567_890}
      ] do
    test "encode_type_b/2 and decode_type_b/2 for bit size #{bit_size}" do
      bit_size = unquote(bit_size)
      byte_size = div(bit_size, 8)
      value = unquote(value)
      {:ok, <<data::binary-size(byte_size)>>} = DataType.encode_type_b(value, bit_size)
      {:ok, ^value, <<>>} = DataType.decode_type_b(data, bit_size)
    end
  end

  # Type C - Unsigned integer
  for {bit_size, value} <- [
        {8, 12},
        {16, 1234},
        {24, 123_456},
        {32, 12_345_678},
        {48, 1_234_567_890},
        {64, 1_234_567_890}
      ] do
    test "encode_type_c/2 and decode_type_c/2 for bit size #{bit_size}" do
      bit_size = unquote(bit_size)
      byte_size = div(bit_size, 8)
      value = unquote(value)
      {:ok, <<data::binary-size(byte_size)>>} = DataType.encode_type_c(value, bit_size)
      {:ok, ^value, <<>>} = DataType.decode_type_c(data, bit_size)
    end
  end

  # Type D - Bool list
  for bit_size <- [8, 16, 24, 32, 48, 64] do
    test "encode_type_d/2 and decode_type_d/2 for bit size #{bit_size}" do
      bit_size = unquote(bit_size)
      byte_size = div(bit_size, 8)

      value =
        Stream.unfold(bit_size, fn
          0 -> nil
          n -> {rem(n, 2) == 0, n - 1}
        end)
        |> Enum.to_list()

      {:ok, <<data::binary-size(byte_size)>>} = DataType.encode_type_d(value, bit_size)
      {:ok, ^value, <<>>} = DataType.decode_type_d(data, bit_size)
    end
  end

  # Type F
  test "test encode_type_f/1 and decode_type_f/1" do
    {:ok, ndt} = NaiveDateTime.new(2021, 11, 18, 09, 39, 0)
    {:ok, <<data::binary-size(4)>>} = DataType.encode_type_f(ndt)
    {:ok, ^ndt, <<>>} = DataType.decode_type_f(data)
  end

  # Type G
  for value <- [~D[2021-12-31], ~D[1999-01-01], ~D[2050-01-01], ~D[1981-01-01], ~D[2080-01-01]] do
    test "test #{value} |> encode_type_g/1 |> decode_type_g/1" do
      value = unquote(Macro.escape(value))
      {:ok, <<data::binary-size(2)>>} = DataType.encode_type_g(value)
      {:ok, ^value, <<>>} = DataType.decode_type_g(data)
    end
  end

  # Type H
  for value <- [0.0, 1.0, 2.0, 0.5, 1.5, :nan, :positive_infinity, :negative_infinity] do
    test "test encode_type_h/1 and decode_type_h/1 for value #{value}" do
      value = unquote(value)
      {:ok, <<data::binary-size(4)>>} = DataType.encode_type_h(value)
      {:ok, ^value, <<>>} = DataType.decode_type_h(data)
    end
  end

  # Type I

  # Type J

  # Type K

  # Type L

  # Type M

  #
  # PeriodicDate
  #
  test "PeriodicDate implements String.Chars" do
    assert "2021-12-31" == PeriodicDate.new!(2021, 12, 31) |> to_string()
    assert "YYYY-12-31" == PeriodicDate.new!(nil, 12, 31) |> to_string()
    assert "2021-MM-31" == PeriodicDate.new!(2021, nil, 31) |> to_string()
    assert "2021-12-DD" == PeriodicDate.new!(2021, 12, nil) |> to_string()
  end

  #
  # Regressions and similar, related to DataType
  #

  describe "Regressions" do
    test "Type G from a DME telegram" do
      bytes = <<0b111_00001, 0b1111_0001>>

      assert {:ok, %PeriodicDate{year: nil, month: 1, day: 1}, <<>>} =
               DataType.decode_type_g(bytes)
    end

    test "Typa A with invalid value" do
      assert {:ok, {:invalid, {:type_a, _}}, <<0x00>>} =
               DataType.decode_type_a(<<0x00, 0x0A, 0x00>>, 16)

      assert {:ok, {:invalid, {:type_a, _}}, <<0xFF>>} =
               DataType.decode_type_a(<<0xFF, 0xFF, 0xFF>>, 16)
    end
  end
end
