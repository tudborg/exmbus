defmodule Exmbus.Dll do

  alias Exmbus.Dll.Wmbus
  alias Exmbus.Dll.Mbus

  def parse(<<0x68, len, len, 0x68, _::binary>> = bin, opts, ctx) do
    # mbus with length
    Mbus.parse(bin, opts, ctx)
  end

  def parse(bin, opts, ctx) do
    # probably wmbus if not mbus
    Wmbus.parse(bin, opts, ctx)
  end

  # getters
  def manufacturer([%Wmbus{manufacturer: m} | _]), do: m
  def manufacturer([_ | ctx]), do: manufacturer(ctx)
  def manufacturer([]), do: nil

  def identification_no([%Wmbus{identification_no: m} | _]), do: m
  def identification_no([_ | ctx]), do: identification_no(ctx)
  def identification_no([]), do: nil

  def version([%Wmbus{version: m} | _]), do: m
  def version([_ | ctx]), do: version(ctx)
  def version([]), do: nil

  def device([%Wmbus{device: m} | _]), do: m
  def device([_ | ctx]), do: device(ctx)
  def device([]), do: nil
end
