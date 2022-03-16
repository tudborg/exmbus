defmodule Exmbus.CI do
  @moduledoc """
  MBus CI codes found in table 2 of EN-13757-7:2018
  """
  @table Exmbus.TableLoader.from_file!(__DIR__, "ci.csv")

  alias Exmbus.Tpl
  alias Exmbus.Ell



  @doc """
  Parse based on the next CI byte, but passing the full binary
  to the responsible parse function, effectivly making this function pure routing based on CI.
  """
  @spec parse(binary(), any(), any()) :: {:ok, term(), rest :: binary()} | {:error, reason :: any()}
  def parse(<<ci, _::binary>>=bin, opts, ctx) do
    case lookup(ci) do
      # If APL then TPL is also implied because EN 13757-7:2018 section 5.2:
      # > The Transport Layer and the Application Layer uses a shared CI-field.
      # > For that reason, a Transport Layer shall be present whenever the Application Layer is used in a message.
      {:ok, {:tpl, _tpl_header, _, _}} ->
        Tpl.parse(bin, opts, ctx)
      {:ok, {:apl, _tpl_header, _, _}} ->
        Tpl.parse(bin, opts, ctx)
      {:ok, {:ell, _ell_type, _, _}} ->
        Ell.parse(bin, opts, ctx)
      {:ok, {symbol, _, what, note}} ->
        raise "Not implemented: CI=#{Exmbus.Debug.u8_to_hex_str(ci)} #{what} (symbol=#{symbol}), #{note}."

      # lookup error:
      {:error, reason} ->
        {:error, reason, ctx}
    end
  end

  # as per the table 2 in the mbus docs
  def layer(ci), do: lookup_element(ci, 0)
  def tpl_type(ci), do: lookup_element(ci, 1)
  def direction(ci), do: lookup_element(ci, 2)
  def higher_layer_protocol(ci), do: lookup_element(ci, 4)

  defp lookup_element(ci, n) do
    case lookup(ci) do
      {:ok, t} -> elem(t, n)
      e        -> e
    end
  end

  # define lookup function based on above table.
  # CI low;CI high;Answer ;Layer ;TPL header type ;Direction ;higher layer protocol note

  Enum.each(@table, fn ({ci_low_bin, ci_high_bin, answer, layer, tpl_header, direction, note}) ->
    {ci_low, ci_high} =
      case {ci_low_bin, ci_high_bin} do
        {<<ci>>, nil} -> {ci, ci}
        {<<l>>, <<h>>} -> {l, h}
      end
    ret =
      case answer do
        :error -> {:error, {:ci_lookup, {layer, {ci_low, ci_high}}}}
        :ok -> {:ok, {layer, tpl_header, direction, note}}
      end
    def lookup(n) when n >= unquote(ci_low) and n <= unquote(ci_high) do
      unquote(Macro.escape(ret))
    end
  end)
  # fallback:
  def lookup(ci), do: {:error, {:unknown_ci, ci}}
end
