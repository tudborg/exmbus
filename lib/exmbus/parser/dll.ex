defmodule Exmbus.Parser.Dll do
  @moduledoc """
  Routes the parsing to the correct Dll parser,
  either Mbus or Wmbus.
  """

  def parse(<<0x68, len, len, 0x68, _::binary>> = bin, opts, ctx) do
    # mbus with length
    Exmbus.Parser.Dll.Mbus.parse(bin, opts, ctx)
  end

  def parse(bin, opts, ctx) do
    # probably wmbus if not mbus
    Exmbus.Parser.Dll.Wmbus.parse(bin, opts, ctx)
  end

  def ci_route(bin, opts, ctx) do
    case Exmbus.Parser.CI.lookup(bin) do
      {:ok, {:tpl, _tpl_header}} ->
        Exmbus.Parser.Tpl.parse(bin, opts, ctx)

      {:ok, {:apl, _tpl_header}} ->
        Exmbus.Parser.Tpl.parse(bin, opts, ctx)

      {:ok, {:ell, _ell_type}} ->
        Exmbus.Parser.Ell.parse(bin, opts, ctx)

      {:ok, {layer, layer_ext}} ->
        raise "Not implemented: wmbus CI layer=#{inspect(layer)} layer_ext=#{inspect(layer_ext)}"

      # lookup error:
      {:error, reason} ->
        {:error, reason, ctx}
    end
  end
end
