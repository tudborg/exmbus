defmodule DataTypeTest do
  use ExUnit.Case
  alias Exmbus.DataType

  doctest Exmbus.DataType, import: true

  # TODO probably property based testing on this module

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
  for {bit_size, value} <- [{8, 12},{16, 1234},{24, 123456},{32, 12345678},{48, 1234567890}] do
    test "encode_type_a/2 and decode_type_a/2 for bit size #{bit_size}" do
      bit_size = unquote(bit_size)
      byte_size = div(bit_size, 8)
      value = unquote(value)
      {:ok, <<data::binary-size(byte_size)>>} = DataType.encode_type_a(value, bit_size)
      {:ok, ^value, <<>>} = DataType.decode_type_a(data, bit_size)
    end
  end

  # Type B - Signed integer
  for {bit_size, value} <- [{8, 12},{16, -1234},{24, 123456},{32, -12345678},{48, 1234567890},{64, 1234567890}] do
    test "encode_type_b/2 and decode_type_b/2 for bit size #{bit_size}" do
      bit_size = unquote(bit_size)
      byte_size = div(bit_size, 8)
      value = unquote(value)
      {:ok, <<data::binary-size(byte_size)>>} = DataType.encode_type_b(value, bit_size)
      {:ok, ^value, <<>>} = DataType.decode_type_b(data, bit_size)
    end
  end

  # Type C - Unsigned integer
  for {bit_size, value} <- [{8, 12},{16, 1234},{24, 123456},{32, 12345678},{48, 1234567890},{64, 1234567890}] do
    test "encode_type_c/2 and decode_type_c/2 for bit size #{bit_size}" do
      bit_size = unquote(bit_size)
      byte_size = div(bit_size, 8)
      value = unquote(value)
      {:ok, <<data::binary-size(byte_size)>>} = DataType.encode_type_c(value, bit_size)
      {:ok, ^value, <<>>} = DataType.decode_type_c(data, bit_size)
    end
  end

  # Type D - Bool list
  for bit_size <- [8,16,24,32,48,64] do
    test "encode_type_d/2 and decode_type_d/2 for bit size #{bit_size}" do
      bit_size = unquote(bit_size)
      byte_size = div(bit_size, 8)

      value =
        Stream.unfold(bit_size, fn
          0 -> nil
          n -> {rem(n, 2) == 0, n-1}
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
  # Regressions and similar, related to DataType
  #

  describe "Regressions" do
    test "Type G from a DME telegram" do
      bytes = <<0x00, 0x00>>
      {:ok, {:periodic, :every_day}, <<>>} = DataType.decode_type_g(bytes)
    end
  end




end
