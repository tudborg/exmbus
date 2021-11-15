defmodule Exmbus.Apl.DataRecord.ValueInformationBlock.VifTablePrimary do

  alias Exmbus.Apl.DataRecord.DataInformationBlock, as: DIB
  alias Exmbus.Apl.DataRecord.ValueInformationBlock, as: VIB
  alias Exmbus.Apl.DataRecord.ValueInformationBlock.VifTableFB, as: FB
  alias Exmbus.Apl.DataRecord.ValueInformationBlock.VifTableFD, as: FD
  alias Exmbus.Apl.DataRecord.ValueInformationBlock.ErrorCode

  ###
  # primary VIF table decoding
  ###
  def parse(<<e::1, 0b0000::4,  n::3, rest::binary>>, opts, ctx),  do: vifes(e, rest, opts, [%VIB{description: :energy,                 multiplier: pow10to(n-3), unit: "Wh"} | ctx])
  def parse(<<e::1, 0b0001::4,  n::3, rest::binary>>, opts, ctx),  do: vifes(e, rest, opts, [%VIB{description: :energy,                 multiplier: pow10to(n),   unit: "J"} | ctx])
  def parse(<<e::1, 0b0010::4,  n::3, rest::binary>>, opts, ctx),  do: vifes(e, rest, opts, [%VIB{description: :volume,                 multiplier: pow10to(n-6), unit: "m^3"} | ctx])
  def parse(<<e::1, 0b0011::4,  n::3, rest::binary>>, opts, ctx),  do: vifes(e, rest, opts, [%VIB{description: :mass,                   multiplier: pow10to(n-6), unit: "kg"} | ctx])
  def parse(<<e::1, 0b01000::5, n::2, rest::binary>>, opts, ctx),  do: vifes(e, rest, opts, [%VIB{description: :on_time,                unit:  on_time_unit(n)} | ctx])
  def parse(<<e::1, 0b01001::5, n::2, rest::binary>>, opts, ctx),  do: vifes(e, rest, opts, [%VIB{description: :operating_time,         unit:  on_time_unit(n)} | ctx])
  def parse(<<e::1, 0b0101::4,  n::3, rest::binary>>, opts, ctx),  do: vifes(e, rest, opts, [%VIB{description: :power,                  multiplier: pow10to(n-3), unit: "W"} | ctx])
  def parse(<<e::1, 0b0110::4,  n::3, rest::binary>>, opts, ctx),  do: vifes(e, rest, opts, [%VIB{description: :power,                  multiplier: pow10to(n),   unit: "J/h"} | ctx])
  def parse(<<e::1, 0b0111::4,  n::3, rest::binary>>, opts, ctx),  do: vifes(e, rest, opts, [%VIB{description: :volume_flow,            multiplier: pow10to(n-6), unit: "m^3/h"} | ctx])
  def parse(<<e::1, 0b1000::4,  n::3, rest::binary>>, opts, ctx),  do: vifes(e, rest, opts, [%VIB{description: :volume_flow_ext,        multiplier: pow10to(n-7), unit: "m^3/min"} | ctx])
  def parse(<<e::1, 0b1001::4,  n::3, rest::binary>>, opts, ctx),  do: vifes(e, rest, opts, [%VIB{description: :volume_flow_ext,        multiplier: pow10to(n-9), unit: "m^3/s"} | ctx])
  def parse(<<e::1, 0b1010::4,  n::3, rest::binary>>, opts, ctx),  do: vifes(e, rest, opts, [%VIB{description: :mass_flow,              multiplier: pow10to(n-3), unit: "kg/h"} | ctx])
  def parse(<<e::1, 0b10110::5, n::2, rest::binary>>, opts, ctx),  do: vifes(e, rest, opts, [%VIB{description: :flow_temperature,       multiplier: pow10to(n-3), unit: "°C"} | ctx])
  def parse(<<e::1, 0b10111::5, n::2, rest::binary>>, opts, ctx),  do: vifes(e, rest, opts, [%VIB{description: :return_temperature,     multiplier: pow10to(n-3), unit: "°C"} | ctx])
  def parse(<<e::1, 0b11000::5, n::2, rest::binary>>, opts, ctx),  do: vifes(e, rest, opts, [%VIB{description: :temperature_difference, multiplier: pow10to(n-3), unit: "K"} | ctx])
  def parse(<<e::1, 0b11001::5, n::2, rest::binary>>, opts, ctx),  do: vifes(e, rest, opts, [%VIB{description: :external_temperature,   multiplier: pow10to(n-3), unit: "°C"} | ctx])
  def parse(<<e::1, 0b11010::5, n::2, rest::binary>>, opts, ctx),  do: vifes(e, rest, opts, [%VIB{description: :pressure,               multiplier: pow10to(n-3), unit: "bar"} | ctx])
  # TYPE: Date and Time
  # - Data field 0b0010, type G
  # - Data field 0b0011, type J
  # - Data field 0b0100, type F
  # - Data field 0b0110, type I
  # - Data field 0b1101, type M (LVAR)
  def parse(<<e::1, 0b1101100::7, rest::binary>>, opts, [%DIB{data_type: :int_or_bin, size: 16} | _]=ctx), do: vifes(e, rest, opts, [%VIB{description: :date, coding: :type_g} | ctx])
  def parse(<<e::1, 0b1101101::7, rest::binary>>, opts, [%DIB{data_type: :int_or_bin, size: 24} | _]=ctx), do: vifes(e, rest, opts, [%VIB{description: :time, coding: :type_j} | ctx])
  def parse(<<e::1, 0b1101101::7, rest::binary>>, opts, [%DIB{data_type: :int_or_bin, size: 32} | _]=ctx), do: vifes(e, rest, opts, [%VIB{description: :naive_datetime, coding: :type_f} | ctx])
  def parse(<<e::1, 0b1101101::7, rest::binary>>, opts, [%DIB{data_type: :int_or_bin, size: 48} | _]=ctx), do: vifes(e, rest, opts, [%VIB{description: :naive_datetime, coding: :type_i} | ctx])
  def parse(<<e::1, 0b1101101::7, rest::binary>>, opts, [%DIB{data_type: :variable_length     } | _]=ctx), do: vifes(e, rest, opts, [%VIB{description: :datetime, coding: :type_m} | ctx])

  def parse(<<e::1, 0b1101110::7, rest::binary>>, opts, ctx),      do: vifes(e, rest, opts, [%VIB{description: :units_for_hca} | ctx])
  def parse(<<e::1, 0b1101111::7, rest::binary>>, _opts, _ctx),    do: error(e, rest, {:reserved, "VIF 0b1101111 reserved for future use"})
  def parse(<<e::1, 0b11100::5, nn::2, rest::binary>>, opts, ctx), do: vifes(e, rest, opts, [%VIB{description: :averaging_duration, unit: on_time_unit(nn)} | ctx])
  def parse(<<e::1, 0b11101::5, nn::2, rest::binary>>, opts, ctx), do: vifes(e, rest, opts, [%VIB{description: :actuality_duration, unit: on_time_unit(nn)} | ctx])
  def parse(<<e::1, 0b1111000::7, rest::binary>>, opts, ctx),      do: vifes(e, rest, opts, [%VIB{description: :fabrication_no} | ctx])
  def parse(<<e::1, 0b1111001::7, rest::binary>>, opts, ctx),      do: vifes(e, rest, opts, [%VIB{description: :enhanced_identification} | ctx])
  def parse(<<e::1, 0b1111010::7, rest::binary>>, opts, ctx),      do: vifes(e, rest, opts, [%VIB{description: :address} | ctx])

  # plain-text VIF:
  # See EN 13757-3:2018(EN) - C.2
  #
  def parse(<<e::1, 0b1111100::7, rest::binary>>, opts, ctx) do
    # first we need to parse all of the extensions as well.
    # we pass in a description set to a marker we can match on it's way out of the vifes/4 again
    # to make sure it hasn't  changed.
    case vifes(e, rest, opts, [%VIB{description: {:user_defined, nil}} | ctx]) do
      # the length in bytes and the ascii unit itself is found after the VIB
      # so we now need to read the unit out from the rest of the data.
      # First we get the length in the first byte:
      {:ok, [%VIB{description: {:user_defined, nil}}=vib | ctx], <<len, rest::binary>>} ->
        # then we match that number of bytes:
        <<rev_ascii_vif::binary-size(len), rest::binary>> = rest
        # The right-most character is transmittet first, so we need to reverse the
        # ascii string to get proper text
        ascii_vif =
          rev_ascii_vif
          |> String.to_charlist()
          |> Enum.reverse()
          |> List.to_string()
        {:ok, [%VIB{vib | description: {:user_defined, ascii_vif}} | ctx], rest}
    end
  end

  def parse(<<e::1, 0b111_1110::7, rest::binary>>, _opts, _ctx), do: error(e, rest, "Any VIF 0x7E / 0xFE not implemented. See 6.4.1 list item d.")

  def parse(<<e::1, 0b111_1111::7, rest::binary>>, _opts, ctx) do
  # Manufacturer specific encoding, 7F / FF.
  # Rest of data-record (including VIFEs) are manufacturer specific.
  {:ok, vifes, rest} =
    case e do
      1 -> consume_vifes(rest, [])
      0 -> {:ok, [], rest}
    end

    |> Enum.map(&({:manufacturer_specific_vife, &1}))

  {:ok, [
    %VIB{
      description: :manufacturer_specific_encoding,
      extensions: Enum.map(vifes, &({:manufacturer_specific_vife, &1}))
    } | ctx], rest}
  #raise "Manufacturer-specific VIF encoding not implemented. See 6.4.1 list item e."
  end

  def parse(<<0b1111_1011, rest::binary>>, opts, ctx), do: FB.parse(rest, opts, ctx)
  def parse(<<0b1111_1101, rest::binary>>, opts, ctx), do: FD.parse(rest, opts, ctx)
  def parse(<<0b1110_1111, _rest::binary>>, _opts, _ctx), do: raise "VIF 0xEF reserved for future use."

  defp on_time_unit(0b00), do: "seconds"
  defp on_time_unit(0b01), do: "minutes"
  defp on_time_unit(0b10), do: "hours"
  defp on_time_unit(0b11), do: "days"

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

  # just consume vifes and return error when done:
  defp error(1, <<e::1, _::7, rest::binary>>, reason), do: error(e, rest, reason)
  defp error(0, rest, reason), do: {:error, reason, rest}

  defp consume_vifes(<<1::1, vife::7, rest::binary>>, acc), do: consume_vifes(rest, [vife | acc])
  defp consume_vifes(<<0::1, vife::7, rest::binary>>, acc), do: {:ok, Enum.reverse([vife | acc]), rest}

  # no more extensions, return
  defp vifes(0, rest, _opts, ctx) do
    {:ok, ctx, rest}
  end
  # VIFE 0bE000XXXX reserved for object actions (master to slave) (6.4.7) or for error codes (slave to master) (6.4.8)
  defp vifes(1, <<e::1, 0b000::3, nnnn::4, rest::binary>>, opts, [%VIB{extensions: exts}=vib | ctx]) do
    case direction_from_ctx(ctx) do
      {:ok, :from_meter} ->
        {:ok, record_error} = ErrorCode.decode(nnnn)
        vifes(e, rest, opts, [%VIB{vib | extensions: [{:record_error, record_error} | exts]} | ctx])
    end
  end

  # From ctx, find layer with direction and call direction function on it:
  defp direction_from_ctx([]), do: {:error, :no_direction}
  defp direction_from_ctx([%Exmbus.Dll.Wmbus{}=wmbus | _tail]), do: Exmbus.Dll.Wmbus.direction(wmbus)
  defp direction_from_ctx([ _ | tail]), do: direction_from_ctx(tail)


end
