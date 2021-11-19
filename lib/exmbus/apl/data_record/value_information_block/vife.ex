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
  def error(1, rest, reason, _ctx) do
    case consume(rest, []) do
      {:ok, _, rest} -> {:error, reason, rest}
    end
  end
  def error(0, rest, reason, _ctx) do
    {:error, reason, rest}
  end

  @doc """
  Parse VIFEs into a %VIB{} struct.
  The first argument is the extension bit from the previous byte.
  When a function call sees a zero from the previous extension bit,
  we know that `rest` isn't part of the VIFE and we can return the accumulated VIB and rest of data.
  """
  def parse(0, rest, _opts, [%VIB{extensions: exts}=vib | ctx]) do
    # on the way out, we reverse the exts list so the first VIFE is first in the list.
    {:ok, [%VIB{vib | extensions: Enum.reverse(exts)} | ctx], rest}
  end
  # VIFE 0bE000XXXX reserved for object actions (master to slave) (6.4.7) or for error codes (slave to master) (6.4.8)
  def parse(1, <<e::1, 0b000::3, xxxx::4, rest::binary>>, opts, [%VIB{table: :main, extensions: exts}=vib | ctx]) do
    case direction_from_ctx(ctx) do
      {:ok, :from_meter} ->
        case ErrorCode.decode(xxxx) do
          {:ok, record_error} ->
            parse(e, rest, opts, [%VIB{vib | extensions: [{:record_error, record_error} | exts]} | ctx])
            # TODO:
            # for now we just pass the reserved numbers through.
            # if they are being used it is most likely because we have not implemented them.
            # I've already seen 0b0_1000 in use in the real world.
          {:error, {:reserved, _}=r} ->
            parse(e, rest, opts, [%VIB{vib | extensions: [{:record_error, r} | exts]} | ctx])

        end
    end
  end
  # next VIFE and rest of block is manufacturer specific
  def parse(1, <<e::1, 0b111_1111::7, rest::binary>>, opts, ctx) do
    parse_manufacturer_specific_vifes(e, rest, opts, ctx)
  end
  def parse(1, <<e::1, vife::7, rest::binary>>, opts, [%VIB{extensions: exts}=vib | ctx]) do
    parse(e, rest, opts, [%VIB{vib | extensions: [{:unknown_vife, vife}| exts]} | ctx])
  end

  defp parse_manufacturer_specific_vifes(0, rest, opts, ctx) do
    parse(0, rest, opts, ctx) # this just "finializes" the vife parse.
  end
  defp parse_manufacturer_specific_vifes(1, <<e::1, vife::7, rest::binary>>, opts, [%VIB{extensions: exts}=vib | ctx]) do
    parse_manufacturer_specific_vifes(e, rest, opts, [%VIB{vib | extensions: [{:manufacturer_specific_vife, vife} | exts]} | ctx])
  end

  # From ctx, find layer with direction and call direction function on it:
  defp direction_from_ctx([]), do: {:error, :no_direction}
  defp direction_from_ctx([%Exmbus.Dll.Wmbus{}=wmbus | _tail]), do: Exmbus.Dll.Wmbus.direction(wmbus)
  defp direction_from_ctx([ _ | tail]), do: direction_from_ctx(tail)

end
