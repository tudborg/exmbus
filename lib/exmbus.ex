defmodule Exmbus do
  @moduledoc """
  Documentation for `Exmbus`.
  """

  alias Exmbus.Dll.Wmbus

  @doc """
  Decodes a binary into at most one Structure.
  Either WMBus or MBus. Will guess depending on frame structure.
  """
  def decode(bin, opts \\ []) do

  end

  def decode_wmbus(bin, opts \\ []) do
    Wmbus.decode(bin, opts)
  end

  def decode_mbus(bin) do
    # TODO properly
    Tpl.decode(bin)
  end
end
