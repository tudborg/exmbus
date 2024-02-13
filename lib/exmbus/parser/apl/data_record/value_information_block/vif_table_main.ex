defmodule Exmbus.Parser.Apl.DataRecord.ValueInformationBlock.VifTableMain do
  @moduledoc """
  Parse module for the primary VIF table.

  EN 13757-3:2018(EN) - 6.4.2 Primary VIFs (main table)
  """

  alias Exmbus.Parser.Context
  alias Exmbus.Parser.Apl.DataRecord.DataInformationBlock, as: DIB
  alias Exmbus.Parser.Apl.DataRecord.ValueInformationBlock, as: VIB
  alias Exmbus.Parser.Apl.DataRecord.ValueInformationBlock.VifTableFB, as: FB
  alias Exmbus.Parser.Apl.DataRecord.ValueInformationBlock.VifTableFD, as: FD
  alias Exmbus.Parser.Apl.DataRecord.ValueInformationBlock.Vife


  # helper to transition the parser into VIFE parsing.
  @compile {:inline, more: 6}
  defp more(e, rest, opts, ctx, description, keywords \\ []) do
    vib = %VIB{
      table: :main,
      description: description,
      multiplier: Keyword.get(keywords, :multiplier, nil),
      unit: Keyword.get(keywords, :unit, nil),
      extensions: [],
      coding: Keyword.get(keywords, :coding, nil)
    }

    ctx = Context.layer(ctx, :vib, vib)

    Vife.parse(e, rest, opts, ctx)
  end

  ###
  # primary VIF table decoding
  ###
  def parse(<<e::1, 0b0000::4,  n::3, rest::binary>>, opts, ctx),  do: more(e, rest, opts, ctx, :energy,                 multiplier: pow10to(n-3), unit: "Wh")
  def parse(<<e::1, 0b0001::4,  n::3, rest::binary>>, opts, ctx),  do: more(e, rest, opts, ctx, :energy,                 multiplier: pow10to(n),   unit: "J")
  def parse(<<e::1, 0b0010::4,  n::3, rest::binary>>, opts, ctx),  do: more(e, rest, opts, ctx, :volume,                 multiplier: pow10to(n-6), unit: "m^3")
  def parse(<<e::1, 0b0011::4,  n::3, rest::binary>>, opts, ctx),  do: more(e, rest, opts, ctx, :mass,                   multiplier: pow10to(n-6), unit: "kg")
  def parse(<<e::1, 0b01000::5, n::2, rest::binary>>, opts, ctx),  do: more(e, rest, opts, ctx, :on_time,                unit:  decode_time_unit(n))
  def parse(<<e::1, 0b01001::5, n::2, rest::binary>>, opts, ctx),  do: more(e, rest, opts, ctx, :operating_time,         unit:  decode_time_unit(n))
  def parse(<<e::1, 0b0101::4,  n::3, rest::binary>>, opts, ctx),  do: more(e, rest, opts, ctx, :power,                  multiplier: pow10to(n-3), unit: "W")
  def parse(<<e::1, 0b0110::4,  n::3, rest::binary>>, opts, ctx),  do: more(e, rest, opts, ctx, :power,                  multiplier: pow10to(n),   unit: "J/h")
  def parse(<<e::1, 0b0111::4,  n::3, rest::binary>>, opts, ctx),  do: more(e, rest, opts, ctx, :volume_flow,            multiplier: pow10to(n-6), unit: "m^3/h")
  def parse(<<e::1, 0b1000::4,  n::3, rest::binary>>, opts, ctx),  do: more(e, rest, opts, ctx, :volume_flow_ext,        multiplier: pow10to(n-7), unit: "m^3/min")
  def parse(<<e::1, 0b1001::4,  n::3, rest::binary>>, opts, ctx),  do: more(e, rest, opts, ctx, :volume_flow_ext,        multiplier: pow10to(n-9), unit: "m^3/s")
  def parse(<<e::1, 0b1010::4,  n::3, rest::binary>>, opts, ctx),  do: more(e, rest, opts, ctx, :mass_flow,              multiplier: pow10to(n-3), unit: "kg/h")
  def parse(<<e::1, 0b10110::5, n::2, rest::binary>>, opts, ctx),  do: more(e, rest, opts, ctx, :flow_temperature,       multiplier: pow10to(n-3), unit: "°C")
  def parse(<<e::1, 0b10111::5, n::2, rest::binary>>, opts, ctx),  do: more(e, rest, opts, ctx, :return_temperature,     multiplier: pow10to(n-3), unit: "°C")
  def parse(<<e::1, 0b11000::5, n::2, rest::binary>>, opts, ctx),  do: more(e, rest, opts, ctx, :temperature_difference, multiplier: pow10to(n-3), unit: "K")
  def parse(<<e::1, 0b11001::5, n::2, rest::binary>>, opts, ctx),  do: more(e, rest, opts, ctx, :external_temperature,   multiplier: pow10to(n-3), unit: "°C")
  def parse(<<e::1, 0b11010::5, n::2, rest::binary>>, opts, ctx),  do: more(e, rest, opts, ctx, :pressure,               multiplier: pow10to(n-3), unit: "bar")
  # TYPE: Date and Time
  # - Data field 0b0010, type G
  # - Data field 0b0011, type J
  # - Data field 0b0100, type F
  # - Data field 0b0110, type I
  # - Data field 0b1101, type M (LVAR)
  def parse(<<e::1, 0b1101100::7, rest::binary>>, opts, %{dib: %DIB{data_type: :int_or_bin, size: 16}}=ctx), do: more(e, rest, opts, ctx, :date, coding: :type_g)
  def parse(<<e::1, 0b1101100::7, rest::binary>>, _pts, %{dib: %DIB{data_type: _, size: _}           }=ctx), do: Vife.error(e, rest, {:invalid, "data field must be 0b0010 from Table 10 in EN 13757-3:2018 \"Meaning depends on data field. Other data fields shall be handled as invalid\""}, ctx)
  def parse(<<e::1, 0b1101101::7, rest::binary>>, opts, %{dib: %DIB{data_type: :int_or_bin, size: 24}}=ctx), do: more(e, rest, opts, ctx, :time, coding: :type_j)
  def parse(<<e::1, 0b1101101::7, rest::binary>>, opts, %{dib: %DIB{data_type: :int_or_bin, size: 32}}=ctx), do: more(e, rest, opts, ctx, :naive_datetime, coding: :type_f)
  def parse(<<e::1, 0b1101101::7, rest::binary>>, opts, %{dib: %DIB{data_type: :int_or_bin, size: 48}}=ctx), do: more(e, rest, opts, ctx, :naive_datetime, coding: :type_i)
  def parse(<<e::1, 0b1101101::7, rest::binary>>, opts, %{dib: %DIB{data_type: :variable_length     }}=ctx), do: more(e, rest, opts, ctx, :datetime, coding: :type_m)

  # Rest after date and time
  def parse(<<e::1, 0b1101110::7, rest::binary>>, opts, ctx),      do: more(e, rest, opts, ctx, :units_for_hca)
  def parse(<<e::1, 0b1101111::7, rest::binary>>, _opts, ctx),     do: Vife.error(e, rest, {:reserved, "VIF 0b1101111 reserved for future use"}, ctx)
  def parse(<<e::1, 0b11100::5, nn::2, rest::binary>>, opts, ctx), do: more(e, rest, opts, ctx, :averaging_duration, unit: decode_time_unit(nn))
  def parse(<<e::1, 0b11101::5, nn::2, rest::binary>>, opts, ctx), do: more(e, rest, opts, ctx, :actuality_duration, unit: decode_time_unit(nn))
  def parse(<<e::1, 0b1111000::7, rest::binary>>, opts, ctx),      do: more(e, rest, opts, ctx, :fabrication_no)
  def parse(<<e::1, 0b1111001::7, rest::binary>>, opts, ctx),      do: more(e, rest, opts, ctx, :enhanced_identification)
  def parse(<<e::1, 0b1111010::7, rest::binary>>, opts, ctx),      do: more(e, rest, opts, ctx, :address)

  # plain-text VIF:
  # See EN 13757-3:2018(EN) - C.2
  #
  def parse(<<e::1, 0b1111100::7, rest::binary>>, opts, ctx) do
    # first we need to parse all of the extensions as well.
    # we pass in a description set to a marker we can match on it's way out of the vifes/4 again
    # to make sure it hasn't changed.
    case more(e, rest, opts, ctx, :plain_text_unit) do
      # the length in bytes and the ascii unit itself is found after the VIB
      # so we now need to read the unit out from the rest of the data.
      # First we get the length in the first byte:
      {:ok, %VIB{description: :plain_text_unit}=vib, <<len, rest::binary>>} ->
        # then we match that number of bytes:
        <<rev_ascii_vif::binary-size(len), rest::binary>> = rest
        # The right-most character is transmittet first, so we need to reverse the
        # ascii string to get proper text
        ascii_vif =
          rev_ascii_vif
          |> String.to_charlist()
          |> Enum.reverse()
          |> List.to_string()
        {:ok, %VIB{vib | unit: ascii_vif}, rest}
    end
  end

  def parse(<<e::1, 0b111_1110::7, rest::binary>>, _opts, ctx), do: Vife.error(e, rest, "Any VIF 0x7E / 0xFE not implemented. See 6.4.1 list item d.", ctx)

  def parse(<<e::1, 0b111_1111::7, rest::binary>>, _opts, _ctx) do
  # Manufacturer specific encoding, 7F / FF.
  # Rest of data-record (including VIFEs) are manufacturer specific.
  {:ok, vifes, rest} =
    case e do
      1 -> Vife.consume(rest, [])
      0 -> {:ok, [], rest}
    end

  {:ok,
    %VIB{
      table: :main,
      description: :manufacturer_specific_encoding,
      extensions: Enum.map(vifes, &({:manufacturer_specific_vife, &1}))
    }, rest}
  end

  def parse(<<0b1111_1011, rest::binary>>, opts, ctx), do: FB.parse(rest, opts, ctx)
  def parse(<<0b1111_1101, rest::binary>>, opts, ctx), do: FD.parse(rest, opts, ctx)
  def parse(<<0b1110_1111, _rest::binary>>, _opts, _ctx), do: raise "VIF 0xEF reserved for future use."




  @doc """
  Unparse a VIB contact from the main table.

  TODO: implement unparsing VIBs with extensions
  """
  def unparse(opts, %VIB{table: :main} = vib) do
    # _unparse for now just parses no-extensions VIBs from the main table
    _unparse(opts, vib)
  end
  defp _unparse(_opts, %VIB{extensions: [], description: :energy,                 multiplier: m, unit: "Wh"}),      do: {:ok, <<0::1, 0b0000::4,  (log10int(m)+3)::3>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :energy,                 multiplier: m, unit: "J"}),       do: {:ok, <<0::1, 0b0001::4,  (log10int(m)+0)::3>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :volume,                 multiplier: m, unit: "m^3"}),     do: {:ok, <<0::1, 0b0010::4,  (log10int(m)+6)::3>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :mass,                   multiplier: m, unit: "kg"}),      do: {:ok, <<0::1, 0b0011::4,  (log10int(m)+6)::3>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :on_time,                               unit:  u}),        do: {:ok, <<0::1, 0b01000::5, (encode_time_unit(u))::2>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :operating_time,                        unit:  u}),        do: {:ok, <<0::1, 0b01001::5, (encode_time_unit(u))::2>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :power,                  multiplier: m, unit: "W"}),       do: {:ok, <<0::1, 0b0101::4,  (log10int(m)+3)::3>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :power,                  multiplier: m, unit: "J/h"}),     do: {:ok, <<0::1, 0b0110::4,  (log10int(m)+0)::3>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :volume_flow,            multiplier: m, unit: "m^3/h"}),   do: {:ok, <<0::1, 0b0111::4,  (log10int(m)+6)::3>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :volume_flow_ext,        multiplier: m, unit: "m^3/min"}), do: {:ok, <<0::1, 0b1000::4,  (log10int(m)+7)::3>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :volume_flow_ext,        multiplier: m, unit: "m^3/s"}),   do: {:ok, <<0::1, 0b1001::4,  (log10int(m)+9)::3>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :mass_flow,              multiplier: m, unit: "kg/h"}),    do: {:ok, <<0::1, 0b1010::4,  (log10int(m)+3)::3>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :flow_temperature,       multiplier: m, unit: "°C"}),      do: {:ok, <<0::1, 0b10110::5, (log10int(m)+3)::2>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :return_temperature,     multiplier: m, unit: "°C"}),      do: {:ok, <<0::1, 0b10111::5, (log10int(m)+3)::2>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :temperature_difference, multiplier: m, unit: "K"}),       do: {:ok, <<0::1, 0b11000::5, (log10int(m)+3)::2>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :external_temperature,   multiplier: m, unit: "°C"}),      do: {:ok, <<0::1, 0b11001::5, (log10int(m)+3)::2>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :pressure,               multiplier: m, unit: "bar"}),     do: {:ok, <<0::1, 0b11010::5, (log10int(m)+3)::2>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :date,           coding: :type_g}),                        do: {:ok, <<0::1, 0b1101100::7>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :time,           coding: :type_j}),                        do: {:ok, <<0::1, 0b1101101::7>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :naive_datetime, coding: :type_f}),                        do: {:ok, <<0::1, 0b1101101::7>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :naive_datetime, coding: :type_i}),                        do: {:ok, <<0::1, 0b1101101::7>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :datetime,       coding: :type_m}),                        do: {:ok, <<0::1, 0b1101101::7>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :units_for_hca}),                                          do: {:ok, <<0::1, 0b1101110::7>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :averaging_duration, unit: u}),                            do: {:ok, <<0::1, 0b11100::5, (encode_time_unit(u))::2>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :actuality_duration, unit: u}),                            do: {:ok, <<0::1, 0b11101::5, (encode_time_unit(u))::2>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :fabrication_no}),                                         do: {:ok, <<0::1, 0b1111000::7>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :enhanced_identification}),                                do: {:ok, <<0::1, 0b1111001::7>>}
  defp _unparse(_opts, %VIB{extensions: [], description: :address}),                                                do: {:ok, <<0::1, 0b1111010::7>>}

  defp _unparse(_opts, %VIB{extensions: es, description: :manufacturer_specific_encoding}) do
    vife_bytes =
      es
      |> Enum.map(fn({:manufacturer_specific_vife, vife}) -> <<vife>> end)
      |> Enum.into(<<>>)
    e_bit = if byte_size(vife_bytes) > 0, do: 1, else: 0
    {:ok, <<e_bit::1, 0b111_1111::7, vife_bytes::binary>>}
  end




  defp decode_time_unit(0b00), do: "seconds"
  defp decode_time_unit(0b01), do: "minutes"
  defp decode_time_unit(0b10), do: "hours"
  defp decode_time_unit(0b11), do: "days"

  defp encode_time_unit("seconds"), do: 0b00
  defp encode_time_unit("minutes"), do: 0b01
  defp encode_time_unit("hours"),   do: 0b10
  defp encode_time_unit("days"),    do: 0b11

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

  defp log10int(n) do
    round(:math.log10(n))
  end

end
