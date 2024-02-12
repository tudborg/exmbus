defmodule Exmbus.Parser do
  @moduledoc """
  Responsible for parsing the binary data into a structured format.
  """
  alias Exmbus.Parser.Context

  def parse(bin, opts \\ nil, ctx \\ nil)

  def parse(bin, opts, ctx) when not is_map(opts) do
    parse(bin, Enum.into(opts || [], %{}), ctx || Context.new())
  end

  def parse(bin, opts, ctx) when is_map(opts) and is_struct(ctx, Context) do
    Exmbus.Parser.Dll.parse(bin, opts, ctx)
  end

  @doc false
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

      {:error, reason} ->
        {:error, Context.add_error(ctx, reason)}
    end
  end
end
