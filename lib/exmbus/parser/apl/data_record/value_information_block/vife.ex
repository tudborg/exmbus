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
  # VIFE 0bE000XXXX reserved for object actions (master to slave) (6.4.7) or for error codes (slave to master) (6.4.8)
  # TODO move down into exts function
  def parse(
        1,
        <<e::1, 0b000::3, xxxx::4, rest::binary>>,
        %{vib: %VIB{table: :main, extensions: exts} = vib} = ctx
      ) do
    case direction_from_ctx(ctx) do
      {:ok, :from_meter} ->
        case ErrorCode.decode(xxxx) do
          {:ok, record_error} ->
            vib = %VIB{vib | extensions: [{:record_error, record_error} | exts]}
            parse(e, rest, %{ctx | vib: vib})

          # for now we just pass the reserved numbers through.
          # if they are being used it is most likely because we have not implemented them.
          # I've already seen 0b0_1000 in use in the real world.
          {:error, {:reserved, _} = r} ->
            vib = %VIB{vib | extensions: [{:record_error, r} | exts]}
            parse(e, rest, %{ctx | vib: vib})
        end
    end
  end

  def parse(1, rest, %{vib: %VIB{extensions: exts} = vib} = ctx) do
    case exts(1, rest, exts) do
      {:ok, rest, exts} -> parse(0, rest, %{ctx | vib: %VIB{vib | extensions: exts}})
    end
  end

  def parse(0, rest, ctx) do
    # when no more extensions, return the vib (which we used as an accumulator so far)
    {:ok, ctx.vib, rest}
  end

  # From ctx, find layer with direction and call direction function on it:

  defp direction_from_ctx(%{dll: %Exmbus.Parser.Dll.Wmbus{} = wmbus}),
    do: Exmbus.Parser.Dll.Wmbus.direction(wmbus)

  defp direction_from_ctx(%{dll: %Exmbus.Parser.Dll.Mbus{} = mbus}),
    do: Exmbus.Parser.Dll.Mbus.direction(mbus)

  defp direction_from_ctx(%{}), do: {:error, :no_direction}

  # Table 15 — Combinable (orthogonal) VIFE-table
  defp exts(0, rest, acc) do
    {:ok, rest, Enum.reverse(acc)}
  end

  defp exts(1, <<e::1, 0b0010010::7, rest::binary>>, acc),
    do: exts(e, rest, [:average_value | acc])

  # EN 13757-3:2018 table 15
  defp exts(1, <<e::1, 0b0010011::7, rest::binary>>, acc),
    do: exts(e, rest, [{:compact_profile, :inverse} | acc])

  # EN 13757-3:2018 table 15
  defp exts(1, <<e::1, 0b0010100::7, rest::binary>>, acc),
    do: exts(e, rest, [:standard_conform | acc])

  # EN 13757-3:2018 table 15
  defp exts(1, <<e::1, 0b0011101::7, rest::binary>>, acc),
    do: exts(e, rest, [:standard_conform | acc])

  # EN 13757-3:2018 table 15
  defp exts(1, <<e::1, 0b0011110::7, rest::binary>>, acc),
    do: exts(e, rest, [{:compact_profile, :register_numbers} | acc])

  # EN 13757-3:2018 table 15
  defp exts(1, <<e::1, 0b0011111::7, rest::binary>>, acc),
    do: exts(e, rest, [{:compact_profile, :compact_profile} | acc])

  defp exts(1, <<e::1, 0b0100000::7, rest::binary>>, acc),
    do: exts(e, rest, [{:per, :interval, :second} | acc])

  defp exts(1, <<e::1, 0b0100001::7, rest::binary>>, acc),
    do: exts(e, rest, [{:per, :interval, :minute} | acc])

  defp exts(1, <<e::1, 0b0100010::7, rest::binary>>, acc),
    do: exts(e, rest, [{:per, :interval, :hour} | acc])

  defp exts(1, <<e::1, 0b0100011::7, rest::binary>>, acc),
    do: exts(e, rest, [{:per, :interval, :day} | acc])

  defp exts(1, <<e::1, 0b0100100::7, rest::binary>>, acc),
    do: exts(e, rest, [{:per, :interval, :week} | acc])

  defp exts(1, <<e::1, 0b0100101::7, rest::binary>>, acc),
    do: exts(e, rest, [{:per, :interval, :month} | acc])

  defp exts(1, <<e::1, 0b0100110::7, rest::binary>>, acc),
    do: exts(e, rest, [{:per, :interval, :year} | acc])

  defp exts(1, <<e::1, 0b0100111::7, rest::binary>>, acc),
    do: exts(e, rest, [{:per, :misc, :revolution_or_measurement} | acc])

  defp exts(1, <<e::1, 0b010100::6, p::1, rest::binary>>, acc) do
    # Increment per input pulse on input channel number p
    exts(e, rest, [{:per, :input_pulse, {:channel_number, p}} | acc])
  end

  defp exts(1, <<e::1, 0b010101::6, p::1, rest::binary>>, acc) do
    # Increment per output pulse on output channel number p
    exts(e, rest, [{:per, :output_pulse, {:channel_number, p}} | acc])
  end

  defp exts(1, <<e::1, 0b0101100::7, rest::binary>>, acc),
    do: exts(e, rest, [{:per, :unit, "l"} | acc])

  defp exts(1, <<e::1, 0b0101101::7, rest::binary>>, acc),
    do: exts(e, rest, [{:per, :unit, "m3"} | acc])

  defp exts(1, <<e::1, 0b0101110::7, rest::binary>>, acc),
    do: exts(e, rest, [{:per, :unit, "kg"} | acc])

  defp exts(1, <<e::1, 0b0101111::7, rest::binary>>, acc),
    do: exts(e, rest, [{:per, :unit, "K"} | acc])

  defp exts(1, <<e::1, 0b0110000::7, rest::binary>>, acc),
    do: exts(e, rest, [{:per, :unit, "kWh"} | acc])

  defp exts(1, <<e::1, 0b0110001::7, rest::binary>>, acc),
    do: exts(e, rest, [{:per, :unit, "GJ"} | acc])

  defp exts(1, <<e::1, 0b0110010::7, rest::binary>>, acc),
    do: exts(e, rest, [{:per, :unit, "kW"} | acc])

  defp exts(1, <<e::1, 0b0110011::7, rest::binary>>, acc),
    do: exts(e, rest, [{:per, :unit, "Kl"} | acc])

  defp exts(1, <<e::1, 0b0110100::7, rest::binary>>, acc),
    do: exts(e, rest, [{:per, :unit, "V"} | acc])

  defp exts(1, <<e::1, 0b0110101::7, rest::binary>>, acc),
    do: exts(e, rest, [{:per, :unit, "A"} | acc])

  defp exts(1, <<e::1, 0b0110110::7, rest::binary>>, acc),
    do: exts(e, rest, [{:multiplied_by, "s"} | acc])

  defp exts(1, <<e::1, 0b0110111::7, rest::binary>>, acc),
    do: exts(e, rest, [{:multiplied_by, "(s/V)"} | acc])

  defp exts(1, <<e::1, 0b0111000::7, rest::binary>>, acc),
    do: exts(e, rest, [{:multiplied_by, "(s/A)"} | acc])

  defp exts(1, <<_::1, 0b0111001::7, _rest::binary>>, _acc),
    do: raise("E011 1001 'Start date(/time) of' not supported")

  defp exts(1, <<e::1, 0b0111010::7, rest::binary>>, acc),
    do: exts(e, rest, [:vif_contains_uncorrected_unit_or_value | acc])

  defp exts(1, <<e::1, 0b0111011::7, rest::binary>>, acc),
    do: exts(e, rest, [{:accumulation_only, :forward_flow} | acc])

  defp exts(1, <<e::1, 0b0111100::7, rest::binary>>, acc),
    do: exts(e, rest, [{:accumulation_only, :backward_flow} | acc])

  defp exts(1, <<e::1, 0b0111101::7, rest::binary>>, acc),
    do: exts(e, rest, [:non_metric | acc])

  defp exts(1, <<e::1, 0b0111110::7, rest::binary>>, acc),
    do: exts(e, rest, [:value_at_base_condition | acc])

  defp exts(1, <<_::1, 0b0111111::7, _rest::binary>>, _acc),
    do: raise("E011 1111 OBIS-declaration not supported")

  defp exts(1, <<e::1, 0b100::3, 0::1, 000::3, rest::binary>>, acc),
    do: exts(e, rest, [{:limit_value, :lower} | acc])

  defp exts(1, <<e::1, 0b100::3, 1::1, 000::3, rest::binary>>, acc),
    do: exts(e, rest, [{:limit_value, :upper} | acc])

  defp exts(1, <<e::1, 0b100::3, 0::1, 001::3, rest::binary>>, acc),
    do: exts(e, rest, [{:number_of_exceeds_of_limit_value, :lower} | acc])

  defp exts(1, <<e::1, 0b100::3, 1::1, 001::3, rest::binary>>, acc),
    do: exts(e, rest, [{:number_of_exceeds_of_limit_value, :upper} | acc])

  defp exts(1, <<e::1, 0b100::3, u::1, f::1, 1::1, b::1, rest::binary>>, acc) do
    # Date (/time) of: b = 0: begin, b = 1: end of, f = 0: first, f= 1: last, u = 0: lower, u = 1: upper limit exceeded
    begin_end = if b == 0, do: :begin, else: :end
    first_last = if f == 0, do: :first, else: :last
    upper_lower = if u == 0, do: :lower, else: :upper
    extension = {:limit_exceeded, upper_lower, first_last, begin_end}
    exts(e, rest, [extension | acc])
  end

  defp exts(1, <<_::1, 0b101::3, _u::1, _f::1, _nn::2, _rest::binary>>, _acc),
    do: raise("E101 ufnn Duration of limit exceed not supported")

  defp exts(1, <<_::1, 0b1100::4, _f::1, _nn::2, _rest::binary>>, _acc),
    do: raise("E110 0fnn Duration of d not supported")

  defp exts(1, <<_::1, 0b1101::4, _u::1, 00::2, _rest::binary>>, _acc),
    do: raise("E110 1u00 Value during lower (u = 0), upper (u = 1) limit exceed not supported")

  defp exts(1, <<e::1, 0b110_1001::7, rest::binary>>, acc),
    do: exts(e, rest, [:leakage_values | acc])

  defp exts(1, <<e::1, 0b110_1101::7, rest::binary>>, acc),
    do: exts(e, rest, [:overflow_values | acc])

  defp exts(1, <<_::1, 0b110_1::4, _u::1, 00::2, _rest::binary>>, _acc),
    do: raise("E110 1f1b 'Date (/time) of' not supported")

  defp exts(1, <<e::1, 0b111_0::4, nnn::3, rest::binary>>, acc),
    do: exts(e, rest, [{:multiplicative_correction_factor, pow10to(nnn - 6)} | acc])

  defp exts(1, <<e::1, 0b111_10::5, nn::2, rest::binary>>, acc),
    do: exts(e, rest, [{:additive_correction_constant, pow10to(nn - 3)} | acc])

  defp exts(1, <<_::1, 0b111_1100::7, _rest::binary>>, _acc),
    do: raise("E111 1100 Extension of combinable (orthogonal) VIFE-Code not supported")

  defp exts(1, <<e::1, 0b111_1101::7, rest::binary>>, acc),
    do: exts(e, rest, [{:multiplicative_correction_factor, 103} | acc])

  defp exts(1, <<e::1, 0b111_1110::7, rest::binary>>, acc),
    do: exts(e, rest, [:future_value | acc])

  defp exts(1, <<e::1, 0b111_1111::7, rest::binary>>, acc),
    do: exts_manufacturer_specific(e, rest, acc)

  defp exts_manufacturer_specific(0, rest, acc) do
    exts(0, rest, acc)
  end

  defp exts_manufacturer_specific(1, <<e::1, vife::7, rest::binary>>, acc) do
    exts_manufacturer_specific(e, rest, [{:manufacturer_specific_vife, vife} | acc])
  end

  defp pow10to(power) do
    case :math.pow(10, power) do
      f when f < 1.0 -> f
      i when i >= 1.0 -> round(i)
    end
  end
end
