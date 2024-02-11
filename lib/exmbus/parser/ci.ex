defmodule Exmbus.Parser.CI do
  @moduledoc """
  MBus CI codes found in table 2 of EN-13757-7:2018

  Note: If APL then TPL is also implied because EN 13757-7:2018 section 5.2:
      The Transport Layer and the Application Layer uses a shared CI-field.
      For that reason, a Transport Layer shall be present whenever the Application Layer is used in a message.
  """
  @table Exmbus.Parser.TableLoader.from_file!(__DIR__, "ci.csv")

  # define lookup function based on above table.
  # CI low;CI high;Answer ;Layer ;TPL header type ;Direction ;higher layer protocol note

  @doc """
  Lookup a CI number against the CI table.
  returns corresponding layer and layer extension, or an error.
  """
  @spec lookup(non_neg_integer() | binary()) ::
          {:ok, {atom, binary}}
          | {:error, {:ci, {atom, {non_neg_integer(), non_neg_integer()}}}}
          | {:error, {:ci, {:unknown, non_neg_integer()}}}
  def lookup(<<ci, _::binary>>) do
    lookup(ci)
  end

  Enum.each(@table, fn {ci_low_bin, ci_high_bin, answer, layer, layer_ext, _direction, _note} ->
    {ci_low, ci_high} =
      case {ci_low_bin, ci_high_bin} do
        {<<ci>>, nil} -> {ci, ci}
        {<<l>>, <<h>>} -> {l, h}
      end

    ret =
      case answer do
        :error -> {:error, {:ci, {layer, {ci_low, ci_high}}}}
        :ok -> {:ok, {layer, layer_ext}}
      end

    def lookup(n) when n >= unquote(ci_low) and n <= unquote(ci_high) do
      unquote(Macro.escape(ret))
    end
  end)

  # fallback:
  def lookup(ci), do: {:error, {:ci, {:unknown, ci}}}
end
