defmodule Exmbus.Apl.DataRecord.ValueInformationBlock.VifTableFB do

  alias Exmbus.Apl.DataRecord.DataInformationBlock, as: DIB
  alias Exmbus.Apl.DataRecord.ValueInformationBlock, as: VIB

  # Table 0xFB from table 14 in EN 13757-3:2018 section 6.4.5
  def parse(<<e::1, 0b000000::6, n::1, rest::binary>>, opts, ctx),   do: vifes(e, rest, opts, [%VIB{description: :energy, multiplier: pow10to(n-1), unit: "MWh"} | ctx])
  def parse(<<e::1, 0b000001::6, n::1, rest::binary>>, opts, ctx),   do: vifes(e, rest, opts, [%VIB{description: :reactive_energy, multiplier: pow10to(n), unit: "kvarh"} | ctx])
  def parse(<<e::1, 0b000010::6, n::1, rest::binary>>, opts, ctx),   do: vifes(e, rest, opts, [%VIB{description: :apparent_energy, multiplier: pow10to(n), unit: "kVAh"} | ctx])
  def parse(<<e::1, 0b000011::6, _::1, rest::binary>>, _opts, _ctx), do: error(e, rest, {:reserved, "VIF E000011n reserved"})
  def parse(<<e::1, 0b000100::6, n::1, rest::binary>>, opts, ctx),   do: vifes(e, rest, opts, [%VIB{description: :energy, multiplier: pow10to(n-1), unit: "GJ"} | ctx])
  def parse(<<e::1, 0b000101::6, _::1, rest::binary>>, _opts, _ctx), do: error(e, rest, {:reserved, "VIF E000101n reserved"})
  def parse(<<e::1, 0b00011::5, nn::2, rest::binary>>, opts, ctx),   do: vifes(e, rest, opts, [%VIB{description: :energy, multiplier: pow10to(nn-1), unit: "MCal"} | ctx])
  def parse(<<e::1, 0b001000::6, n::1, rest::binary>>, opts, ctx),   do: vifes(e, rest, opts, [%VIB{description: :volume, multiplier: pow10to(n+2), unit: "m^3"} | ctx])
  def parse(<<e::1, 0b001001::6, _::1, rest::binary>>, _opts, _ctx), do: error(e, rest, {:reserved, "VIF E001001n reserved"})
  def parse(<<e::1, 0b00101::5, nn::2, rest::binary>>, opts, ctx),   do: vifes(e, rest, opts, [%VIB{description: :reactive_power, multiplier: pow10to(nn-3), unit: "kVAR"} | ctx])
  def parse(<<e::1, 0b001100::6, n::1, rest::binary>>, opts, ctx),   do: vifes(e, rest, opts, [%VIB{coding: fb_remark_d(ctx), description: :mass, multiplier: pow10to(n+2), unit: "t"} | ctx])
  def parse(<<e::1, 0b001101::6, n::1, rest::binary>>, opts, ctx),   do: vifes(e, rest, opts, [%VIB{coding: fb_remark_d(ctx), description: :relative_humidity, multiplier: pow10to(n-1), unit: "%"} | ctx])
  def parse(<<e::1, n::7, rest::binary>>, _opts, _ctx) when n >= 0b001_1100 and n <= 0b001_1111, do: error(e, rest, {:reserved, "VIF E0011100 - E0011111 reserved"})
  def parse(<<e::1, 0b0100000::7, rest::binary>>, opts, ctx),        do: vifes(e, rest, opts, [%VIB{description: :volume, unit: "ft^3"} | ctx])
  def parse(<<e::1, 0b0100001::7, rest::binary>>, opts, ctx),        do: vifes(e, rest, opts, [%VIB{description: :volume, multiplier: 0.1, unit: "ft^3"} | ctx])
  def parse(<<e::1, n::7, rest::binary>>, _opts, _ctx) when n >= 0b010_0010 and n <= 0b010_0111, do: error(e, rest, {:reserved, "VIF E0100010 - E0100111 were used until 2004, now they are reserved for future use."})
  def parse(<<e::1, 0b010100::6, n::1, rest::binary>>, opts, ctx),   do: vifes(e, rest, opts, [%VIB{description: :power, multiplier: pow10to(n-1), unit: "MW"} | ctx])
  def parse(<<e::1, 0b0101010::7, rest::binary>>, opts, ctx),        do: vifes(e, rest, opts, [%VIB{description: :phase_volt_to_volt, unit: "°"} | ctx])
  def parse(<<e::1, 0b0101011::7, rest::binary>>, opts, ctx),        do: vifes(e, rest, opts, [%VIB{description: :phase_volt_to_current, unit: "°"} | ctx])
  def parse(<<e::1, 0b01011::5, nn::2, rest::binary>>, opts, ctx),   do: vifes(e, rest, opts, [%VIB{description: :frequency, multiplier: pow10to(nn-3), unit: "Hz"} | ctx])
  def parse(<<e::1, 0b011000::6, n::1, rest::binary>>, opts, ctx),   do: vifes(e, rest, opts, [%VIB{description: :power, multiplier: pow10to(n-1), unit: "GJ/h"} | ctx])
  def parse(<<e::1, 0b011001::6, _::1, rest::binary>>, _opts, _ctx), do: error(e, rest, {:reserved, "VIF E011001n reserved"})
  def parse(<<e::1, 0b01101::5, nn::2, rest::binary>>, opts, ctx),   do: vifes(e, rest, opts, [%VIB{description: :apparent_power, multiplier: pow10to(nn-3), unit: "kVA"} | ctx])
  def parse(<<e::1, n::7, rest::binary>>, _opts, _ctx) when n >= 0b0111000 and n <= 0b1010111, do: error(e, rest, {:reserved, "E0111000 - E1010111 reserved"})
  def parse(<<e::1, n::7, rest::binary>>, _opts, _ctx) when n >= 0b010_0010 and n <= 0b010_0111, do: error(e, rest, {:reserved, "VIF E1011000 - E1100111 were used until 2004, now they are reserved for future use."})
  def parse(<<e::1, 0b11101::5, nn::2, rest::binary>>, opts, ctx),   do: vifes(e, rest, opts, [%VIB{description: :temperature_limit, multiplier: pow10to(nn-3), unit: "°C"} | ctx])
  def parse(<<e::1, 0b1111::4, nnn::3, rest::binary>>, opts, ctx),   do: vifes(e, rest, opts, [%VIB{description: :cumulative_max_active_power, multiplier: pow10to(nnn-3), unit: "W"} | ctx])
  def parse(<<e::1, 0b1101000::7, rest::binary>>, opts, ctx),        do: vifes(e, rest, opts, [%VIB{coding: fb_remark_d(ctx), description: :resulting_rating_factor_k, multiplier: pow2to(-12), unit: "units for HCA"} | ctx])
  def parse(<<e::1, 0b1101001::7, rest::binary>>, opts, ctx),        do: vifes(e, rest, opts, [%VIB{coding: fb_remark_d(ctx), description: :thermal_output_rating_factor_kq, multiplier: pow2to(-12), unit: "W"} | ctx])
  # skipping some HCA things here

  def parse(<<vif, _rest::binary>>, _opts, ctx) do
    raise "decoding from VIF linear extension table 0xFB not implemented. VIFE was: #{Exmbus.Debug.u8_to_binary_str(vif)}, ctx was: #{inspect ctx}"
  end


  # TODO: Try to undertand this remark k of table 12 (page 19), section is 6.4.4.1
  # NOTE: This is also remark d in table 14 (VIF table 0xFB)
  # This function implements remark K in table 12 which says:
  # "Binary data (see Table 4) shall be interpreted as data type A (unsigned BCD) or data type C (unsigned integer) according to Annex A."
  # I read this as: if the coding is :int_or_bin then decode it as either type A or type C, but it isn't clear
  # to me when to do A and when to do C.
  # Maybe what it SHOULD have set is that if the coding is int/binary then do type C, if it's BCD then do type A.
  # Or maybe it says that the binary (as in the raw) data should be decoded as either BCD or UINT, and
  # anything else is an error, but that also seems weird for something like manufacturer, customer, etc.
  defp fb_remark_d([%DIB{data_type: :int_or_bin} | _]) do
    :type_c
  end
  defp fb_remark_d([%DIB{data_type: :variable_length} | _]) do
    nil # lvar coding is determined by the lvar
  end
  defp fb_remark_d([%DIB{data_type: :bcd} | _]) do
    :type_a
  end

  # returns 10^power but makes sure it is only a float if it has to be.
  # since we know it's 10^pow we can round to integers when the result is >= 1.0
  # we do this because that way we can maintain the appearance (and infinite precision) of BEAM integers
  # where possible, however this also means that the datatype of the final multiplication differs
  # depending on the datatype, allowing the same kind of value to be both float and integer.
  # If this is relevant, the user can coerce from int to float where needed. The other way is harder.
  defp pow10to(power) do
    case :math.pow(10, power) do
      f when f < 1.0 -> f
      i when i >= 1.0 -> round(i)
    end
  end

  defp pow2to(power) do
    case :math.pow(2, power) do
      f when f < 1.0 -> f
      i when i >= 1.0 -> round(i)
    end
  end

  # just consume vifes and return error when done:
  defp error(1, <<e::1, _::7, rest::binary>>, reason), do: error(e, rest, reason)
  defp error(0, rest, reason), do: {:error, reason, rest}

  # no more extensions, return
  defp vifes(0, rest, _opts, ctx) do
    {:ok, ctx, rest}
  end

end
