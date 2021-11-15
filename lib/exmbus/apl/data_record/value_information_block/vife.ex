defmodule Exmbus.Apl.DataRecord.ValueInformationBlock.Vife do
  @moduledoc """
  Takes care of VIF extension parsing.

  It might be possible to refactor this away at some point, but right
  now it seems like a lot of the VIFE functionality is the same across
  VIF tables, so we gather it all here.
  """

  alias Exmbus.Apl.DataRecord.ValueInformationBlock, as: VIB
  alias Exmbus.Apl.DataRecord.ValueInformationBlock.ErrorCode

  @doc """
  Consume all VIFE bytes and return them.
  Useful for ignoring VIFE.
  """
  def consume(<<1::1, vife::7, rest::binary>>, acc), do: consume(rest, [vife | acc])
  def consume(<<0::1, vife::7, rest::binary>>, acc), do: {:ok, Enum.reverse([vife | acc]), rest}

  @doc """
  Ignore VIFE and return {:error, reason, rest}
  """
  def error(1, rest, reason) do
    case consume(rest, []) do
      {:ok, _, rest} -> {:error, reason, rest}
    end
  end
  def error(0, rest, reason) do
    {:error, reason, rest}
  end

  # no more extensions, return
  def parse(0, rest, _opts, ctx) do
    {:ok, ctx, rest}
  end
  # VIFE 0bE000XXXX reserved for object actions (master to slave) (6.4.7) or for error codes (slave to master) (6.4.8)
  def parse(1, <<e::1, 0b000::3, nnnn::4, rest::binary>>, opts, [%VIB{table: :main, extensions: exts}=vib | ctx]) do
    case direction_from_ctx(ctx) do
      {:ok, :from_meter} ->
        {:ok, record_error} = ErrorCode.decode(nnnn)
        parse(e, rest, opts, [%VIB{vib | extensions: [{:record_error, record_error} | exts]} | ctx])
    end
  end
  def parse(1, <<e::1, vife::7, rest::binary>>, opts, [%VIB{extensions: exts}=vib | ctx]) do
    parse(e, rest, opts, [%VIB{vib | extensions: [{:unknown_vife, vife}| exts]} | ctx])
  end

  # From ctx, find layer with direction and call direction function on it:
  defp direction_from_ctx([]), do: {:error, :no_direction}
  defp direction_from_ctx([%Exmbus.Dll.Wmbus{}=wmbus | _tail]), do: Exmbus.Dll.Wmbus.direction(wmbus)
  defp direction_from_ctx([ _ | tail]), do: direction_from_ctx(tail)

end
