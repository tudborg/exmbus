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

end
