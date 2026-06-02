defmodule Exmbus.Parser.Apl.DataRecord.ValueInformationBlock.Vife do
  @moduledoc """
  Takes care of VIF extension parsing.

  It might be possible to refactor this away at some point, but right
  now it seems like a lot of the VIFE functionality is the same across
  VIF tables, so we gather it all here.
  """

  alias Exmbus.Parser.Apl.DataRecord.ValueInformationBlock, as: VIB
  alias Exmbus.Parser.Apl.DataRecord.ValueInformationBlock.ErrorCode

  @doc """
  Consume all VIFE bytes and return them.
  Useful for ignoring VIFE.
  """
  def consume(<<1::1, vife::7, rest::binary>>, acc), do: consume(rest, [vife | acc])
  def consume(<<0::1, vife::7, rest::binary>>, acc), do: {:ok, Enum.reverse([vife | acc]), rest}

  @doc """
  Ignore VIFE and return {:error, reason, rest}
  """
  def error(1, rest, _dib, _ctx, reason) do
    case consume(rest, []) do
      {:ok, _, rest} -> {:error, reason, rest}
    end
  end

  def error(0, rest, _dib, _ctx, reason) do
    {:error, reason, rest}
  end

  # Parse VIFEs into a %VIB{} struct.
  # The first argument is the extension bit from the previous byte.
  # When a function call sees a zero from the previous extension bit,
  # we know that `rest` isn't part of the VIFE and we can return the accumulated VIB and rest of data.
  def parse(1, rest, dib, %VIB{extensions: exts} = vib, ctx) do
    case exts(1, rest, ctx, exts) do
      {:ok, rest, exts} -> parse(0, rest, dib, %{vib | extensions: exts}, ctx)
    end
  end

  def parse(0, rest, _dib, vib, _ctx) do
    # when no more extensions, return the vib (which we used as an accumulator)
    {:ok, vib, rest}
  end

  # From ctx, find layer with direction and call direction function on it:

  defp direction_from_ctx(%{dll: %Exmbus.Parser.Dll.Wmbus{} = wmbus}),
    do: Exmbus.Parser.Dll.Wmbus.direction(wmbus)

  defp direction_from_ctx(%{dll: %Exmbus.Parser.Dll.Mbus{} = mbus}),
    do: Exmbus.Parser.Dll.Mbus.direction(mbus)

  defp direction_from_ctx(_), do: {:error, :unknown_direction}

  # Table 15 — Combinable (orthogonal) VIFE-table
  defp exts(0, rest, _ctx, acc) do
    {:ok, rest, Enum.reverse(acc)}
  end

  # VIFE 0bE000XXXX reserved for object actions (master to slave) (6.4.7) or for error codes (slave to master) (6.4.8)
  defp exts(1, <<e::1, 0b000::3, xxxx::4, rest::binary>>, ctx, acc) do
    case direction_from_ctx(ctx) do
      res when res in [{:ok, :from_meter}, {:error, :unknown_direction}] ->
        case ErrorCode.decode(xxxx) do
          {:ok, record_error} ->
            exts(e, rest, ctx, [{:record_error, record_error} | acc])

          # for now we just pass the reserved numbers through.
          # if they are being used it is most likely because we have not implemented them.
          # I've already seen 0b0_1000 in use in the real world.
          {:error, {:reserved, _} = r} ->
            exts(e, rest, ctx, [{:record_error, r} | acc])
        end
    end
  end

  defp exts(1, <<e::1, 0b0010010::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [:average_value | acc])

  # EN 13757-3:2018 table 15
  defp exts(1, <<e::1, 0b0010011::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:compact_profile, :inverse} | acc])

  # EN 13757-3:2018 table 15
  defp exts(1, <<e::1, 0b0010100::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [:standard_conform | acc])

  # EN 13757-3:2018 table 15
  defp exts(1, <<e::1, 0b0011101::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [:standard_conform | acc])

  # EN 13757-3:2018 table 15
  defp exts(1, <<e::1, 0b0011110::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:compact_profile, :register_numbers} | acc])

  # EN 13757-3:2018 table 15
  defp exts(1, <<e::1, 0b0011111::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:compact_profile, :compact_profile} | acc])

  defp exts(1, <<e::1, 0b0100000::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:per, :interval, :second} | acc])

  defp exts(1, <<e::1, 0b0100001::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:per, :interval, :minute} | acc])

  defp exts(1, <<e::1, 0b0100010::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:per, :interval, :hour} | acc])

  defp exts(1, <<e::1, 0b0100011::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:per, :interval, :day} | acc])

  defp exts(1, <<e::1, 0b0100100::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:per, :interval, :week} | acc])

  defp exts(1, <<e::1, 0b0100101::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:per, :interval, :month} | acc])

  defp exts(1, <<e::1, 0b0100110::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:per, :interval, :year} | acc])

  defp exts(1, <<e::1, 0b0100111::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:per, :misc, :revolution_or_measurement} | acc])

  defp exts(1, <<e::1, 0b010100::6, p::1, rest::binary>>, ctx, acc) do
    # Increment per input pulse on input channel number p
    exts(e, rest, ctx, [{:per, :input_pulse, {:channel_number, p}} | acc])
  end

  defp exts(1, <<e::1, 0b010101::6, p::1, rest::binary>>, ctx, acc) do
    # Increment per output pulse on output channel number p
    exts(e, rest, ctx, [{:per, :output_pulse, {:channel_number, p}} | acc])
  end

  defp exts(1, <<e::1, 0b0101100::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:per, :unit, "l"} | acc])

  defp exts(1, <<e::1, 0b0101101::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:per, :unit, "m3"} | acc])

  defp exts(1, <<e::1, 0b0101110::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:per, :unit, "kg"} | acc])

  defp exts(1, <<e::1, 0b0101111::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:per, :unit, "K"} | acc])

  defp exts(1, <<e::1, 0b0110000::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:per, :unit, "kWh"} | acc])

  defp exts(1, <<e::1, 0b0110001::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:per, :unit, "GJ"} | acc])

  defp exts(1, <<e::1, 0b0110010::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:per, :unit, "kW"} | acc])

  defp exts(1, <<e::1, 0b0110011::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:per, :unit, "Kl"} | acc])

  defp exts(1, <<e::1, 0b0110100::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:per, :unit, "V"} | acc])

  defp exts(1, <<e::1, 0b0110101::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:per, :unit, "A"} | acc])

  defp exts(1, <<e::1, 0b0110110::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:multiplied_by, "s"} | acc])

  defp exts(1, <<e::1, 0b0110111::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:multiplied_by, "(s/V)"} | acc])

  defp exts(1, <<e::1, 0b0111000::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:multiplied_by, "(s/A)"} | acc])

  defp exts(1, <<e::1, 0b0111001::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [:start_date_slash_time_of | acc])

  defp exts(1, <<e::1, 0b0111010::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [:vif_contains_uncorrected_unit_or_value | acc])

  defp exts(1, <<e::1, 0b0111011::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:accumulation_only, :forward_flow} | acc])

  defp exts(1, <<e::1, 0b0111100::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:accumulation_only, :backward_flow} | acc])

  defp exts(1, <<e::1, 0b0111101::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [:non_metric | acc])

  defp exts(1, <<e::1, 0b0111110::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [:value_at_base_condition | acc])

  defp exts(1, <<e::1, 0b0111111::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [:obis_declaration | acc])

  defp exts(1, <<e::1, 0b100::3, 0::1, 000::3, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:limit_value, :lower} | acc])

  defp exts(1, <<e::1, 0b100::3, 1::1, 000::3, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:limit_value, :upper} | acc])

  defp exts(1, <<e::1, 0b100::3, 0::1, 001::3, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:number_of_exceeds_of_limit_value, :lower} | acc])

  defp exts(1, <<e::1, 0b100::3, 1::1, 001::3, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:number_of_exceeds_of_limit_value, :upper} | acc])

  # E100 uf1b
  # Date (/time) of: b=0:begin, b=1:end, f=0:first, f=1:last, u=0:lower, u=1:upper limit exceed
  defp exts(1, <<e::1, 0b100::3, u::1, f::1, 1::1, b::1, rest::binary>>, ctx, acc) do
    begin_end = if b == 0, do: :begin, else: :end
    first_last = if f == 0, do: :first, else: :last
    upper_lower = if u == 0, do: :lower, else: :upper
    extension = {:limit_exceed, upper_lower, first_last, begin_end}
    exts(e, rest, ctx, [extension | acc])
  end

  # E101 ufnn
  # Duration of limit exceed: f=0:first, f=1:last, u=0:lower, u=1:upper limit exceed,
  # nn=00:second, nn=01:minute, nn=10:hour, nn=11:day
  defp exts(1, <<e::1, 0b101::3, u::1, f::1, nn::2, rest::binary>>, ctx, acc) do
    first_last = if f == 0, do: :first, else: :last
    upper_lower = if u == 0, do: :lower, else: :upper

    duration_type =
      case nn do
        0b00 -> :second
        0b01 -> :minute
        0b10 -> :hour
        0b11 -> :day
      end

    extension = {:duration_of_limit_exceed, upper_lower, first_last, duration_type}
    exts(e, rest, ctx, [extension | acc])
  end

  # E110 0fnn
  # Duration of d
  # f=0:first, f=1:last, nn=00:second, nn=01:minute, nn=10:hour, nn=11:day
  defp exts(1, <<e::1, 0b1100::4, f::1, nn::2, rest::binary>>, ctx, acc) do
    first_last = if f == 0, do: :first, else: :last

    date_type =
      case nn do
        0b00 -> :second
        0b01 -> :minute
        0b10 -> :hour
        0b11 -> :day
      end

    extension = {:duration_of_d, first_last, date_type}
    exts(e, rest, ctx, [extension | acc])
  end

  defp exts(1, <<e::1, 0b110_1::4, u::1, 00::2, rest::binary>>, ctx, acc) do
    bound = if(u == 0, do: :lower, else: :upper)
    exts(e, rest, ctx, [{:value_during_limit_exceed, bound} | acc])
  end

  defp exts(1, <<e::1, 0b110_1001::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [:leakage_values | acc])

  defp exts(1, <<e::1, 0b110_1101::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [:overflow_values | acc])

  defp exts(1, <<e::1, 0b110_1::4, f::1, 1::1, b::1, rest::binary>>, ctx, acc) do
    begin_end = if b == 0, do: :begin, else: :end
    first_last = if f == 0, do: :first, else: :last
    extension = {:date_time_of, first_last, begin_end}
    exts(e, rest, ctx, [extension | acc])
  end

  defp exts(1, <<e::1, 0b111_0::4, nnn::3, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:multiplicative_correction_factor, pow10to(nnn - 6)} | acc])

  defp exts(1, <<e::1, 0b111_10::5, nn::2, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:additive_correction_constant, pow10to(nn - 3)} | acc])

  defp exts(1, <<e::1, 0b111_1100::7, rest::binary>>, ctx, acc),
    do: exts_table_fc(e, rest, ctx, acc)

  defp exts(1, <<e::1, 0b111_1101::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [{:multiplicative_correction_factor, 103} | acc])

  defp exts(1, <<e::1, 0b111_1110::7, rest::binary>>, ctx, acc),
    do: exts(e, rest, ctx, [:future_value | acc])

  defp exts(1, <<e::1, 0b111_1111::7, rest::binary>>, ctx, acc),
    do: exts_manufacturer_specific(e, rest, ctx, acc)

  # for now, just write a "we do not support VIFE extension table FC" extension:
  defp exts_table_fc(1, <<e::1, unknown::7, rest::binary>>, ctx, acc) do
    exts(e, rest, ctx, [{:unsupported_vife_extension_table_fc, unknown} | acc])
  end

  # this should not happen, because it is pointless to move to the extension table and then not have an extension in here,
  # but we don't want to crash on it, so we just continue.
  defp exts_table_fc(0, rest, ctx, acc) do
    exts(0, rest, ctx, acc)
  end

  # I've considered having this fall-through, but I actually think it is possible to handle
  # all VIFE cases instead, and give more specific errors, so for now, we'll do that.
  # defp exts(1, rest, ctx, acc) do
  #   case consume(rest, []) do
  #     {:ok, unknown_vifes, rest} -> exts(0, rest, ctx, [{:unknown_vifes, unknown_vifes} | acc])
  #   end
  # end

  defp exts_manufacturer_specific(0, rest, ctx, acc) do
    exts(0, rest, ctx, acc)
  end

  defp exts_manufacturer_specific(1, <<e::1, vife::7, rest::binary>>, ctx, acc) do
    exts_manufacturer_specific(e, rest, ctx, [{:manufacturer_specific_vife, vife} | acc])
  end

  defp pow10to(power) do
    case :math.pow(10, power) do
      f when f < 1.0 -> f
      i when i >= 1.0 -> round(i)
    end
  end
end
