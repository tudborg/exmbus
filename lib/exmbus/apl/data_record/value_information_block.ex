defmodule Exmbus.Apl.DataRecord.ValueInformationBlock do
  @moduledoc """
  The Value Information Block utilities
  """

  alias Exmbus.Apl.DataRecord.DataInformationBlock, as: DIB
  alias __MODULE__, as: VIB

  defstruct [
    # VIB fields:
    description: nil, # An atom describing the value. This is an atomized version of the "Description" from the documentation.
    multiplier: nil,  # A multiplier to apply to the data. It's part of the VIF(E) information.
    unit: nil,        # A string giving the unit of the value (e.g. kJ/h or °C)
    extensions: [],   # A list of extensions that might modify the meaning of the data.

    # Implied by a combination of the above
    coding: nil,       # If set, decode according to this datatype instead of what is found in the DIB
    #                  # Options are: type_a, type_b, type_c, type_d, type_f, type_g,
    #                  #              type_h, type_i, type_j, type_k, type_l, type_m
  ]



  def parse(bin, opts, ctx) do
    # the :main is the default decode table name
    parse(:main, bin, opts, ctx)
  end

  # linear VIF-extension: EF, reserved for future use
  defp parse(_table, <<0xEF, _rest::binary>>, _opts, _ctx) do
    raise "VIF 0xEF reserved for future use."
  end
  # plain-text VIF:
  defp parse(table, <<_::1, 0b111_1100::7, rest::binary>>, opts, ctx) do
    case parse_vifes(table, rest, opts, [%VIB{} | ctx]) do
      {:ok, [%VIB{}=vib | ctx], <<len, rest::binary>>} ->
        # the unit is found after the VIB, so we now need to read the unit out from the rest of the data
        <<ascii_vif::binary-size(len), rest::binary>> = rest
        {:ok, [%VIB{vib | description: {:user_defined, ascii_vif}} | ctx], rest}
    end
  end
  # Any VIF: 7E / FE
  # This VIF-Code can be used in direction master to slave for readout selection of all VIFs.
  # See special function in 6.3.3
  defp parse(_table, <<_::1, 0b1111110::7, _rest::binary>>, _opts, _ctx) do
    raise "Any VIF 0x7E / 0xFE not implemented. See 6.4.1 list item d."
  end
  # Manufacturer specific encoding, 7F / FF.
  # Rest of data-record (including VIFEs) are manufacturer specific.
  defp parse(_table, <<_::1, 0b1111111::7, rest::binary>>, _opts, ctx) do
    header = %__MODULE__{description: nil, extensions: []}
    {vifes, rest} = split_by_extension_bit(rest)

    manufacturer_specific_vifes =
      vifes
      |> :binary.bin_to_list()
      |> Enum.map(&({:manufacturer_specific_vife, &1}))

    {:ok, [
      %__MODULE__{
        header |
        description: :manufacturer_specific_encoding,
        extensions: manufacturer_specific_vifes
      } | ctx
      ], rest}
    #raise "Manufacturer-specific VIF encoding not implemented. See 6.4.1 list item e."
  end
  # linear VIF-extension: 0xFD, decode vif from table 14.
  defp parse(_table, <<0xFD, rest::binary>>, opts, ctx) do
    parse(0xFD, rest, opts, ctx)
  end
  # linear VIF-extension: FB, decode vif from table 12.
  defp parse(_table, <<0xFB, rest::binary>>, opts, ctx) do
    parse(0xFB, rest, opts, ctx)
  end
  defp parse(table, <<vif::binary-size(1), rest::binary>>, opts, [%DIB{}=dib | _]=ctx) do
    case decode_vif(table, dib, vif) do
      %VIB{}=vib ->
        case vif do
          # Do we have VIF extensions?
          # yes:
          <<1::1, _::7>> -> parse_vifes(table, rest, opts, [vib | ctx])
          # no:
          <<0::1, _::7>> -> {:ok, [vib | ctx], rest}
        end
    end
  end

  # VIFE 0bE000XXXX reserved for object actions (master to slave) (6.4.7) or for error codes (slave to master) (6.4.8)
  defp parse_vifes(:main, <<ext::1, 0b000::3, nnnn::4, rest::binary>>, opts, [%VIB{extensions: exts}=vib | ctx]) do
    case direction_from_ctx(ctx) do
      {:ok, :from_meter} ->
        {:ok, record_error} = decode_error_code(nnnn)
        new_ctx = [%VIB{vib | extensions: [{:record_error, record_error} | exts]} | ctx]
        case ext do
          0 -> {:ok, new_ctx, rest}
          1 -> parse_vifes(:main, rest, opts, new_ctx)
        end
    end
  end
  defp parse_vifes(_table, <<_::1, 0b0010000::7, _rest::binary>>, _opts, _ctx) do
    raise "VIFE E0010000 reserved"
  end
  defp parse_vifes(_table, <<_::1, 0b0010001::7, _rest::binary>>, _opts, _ctx) do
    raise "VIFE E0010001 reserved"
  end
  # Unknown VIFE (We have not implemented a specific atom for it, and don't know how it affects the value)
  defp parse_vifes(table, <<ext::1, vife::7, rest::binary>>, opts, [%VIB{extensions: exts}=vib | ctx]) do
    # the vife is unknown. We add it as unknown to the extensions list.
    new_ctx = [%VIB{vib | extensions: [{{:unknown_vife, vife, table}} | exts]} | ctx]
    case ext do
      0 -> {:ok, new_ctx, rest}
      1 -> parse_vifes(table, rest, opts, new_ctx)
    end
  end



  @doc """
  Splits a binary into two, so that the left side contains a binary of all bytes
  up to and including a byte without it's extension bit (MSB) set.

  This is the way DRH blocks are seperated.

    iex> split_by_extension_bit(<<0b0000_0000, 0xFF>>)
    {<<0x00>>, <<0xFF>>}

    iex> split_by_extension_bit(<<0b0000_0000, 0b0000_0000, 0xFF>>)
    {<<0x00>>, <<0x00, 0xFF>>}

    iex> split_by_extension_bit(<<0b1000_0000, 0b0000_0000, 0xFF>>)
    {<<0b10000000, 0b00000000>>, <<0xFF>>}
  """
  @spec split_by_extension_bit(binary()) :: {binary(), binary()}
  def split_by_extension_bit(<<byte::binary-size(1), rest::binary>>) do
    case byte do
      <<0::1, _::7>> ->
        {byte, rest}
      <<1::1, _::7>> ->
        {tail, rest} = split_by_extension_bit(rest)
        {<<byte::binary, tail::binary>>, rest}
    end
  end


  defp direction_from_ctx([]) do
    {:error, :no_direction}
  end
  defp direction_from_ctx([%Exmbus.Dll.Wmbus{}=wmbus | _tail]) do
    Exmbus.Dll.Wmbus.direction(wmbus)
  end
  defp direction_from_ctx([ _ | tail]) do
    direction_from_ctx(tail)
  end

  # Section 6.4.8 - Table 18 - Codes for record errors
  # DIF errors:
  defp decode_error_code(0b0_0000), do: {:ok, :none}
  defp decode_error_code(0b0_0001), do: {:ok, :too_many_difes}
  defp decode_error_code(0b0_0010), do: {:ok, :storage_number_not_implemented}
  defp decode_error_code(0b0_0011), do: {:ok, :unit_number_not_implemented}
  defp decode_error_code(0b0_0100), do: {:ok, :tariff_number_not_implemented}
  defp decode_error_code(0b0_0101), do: {:ok, :function_not_implemented}
  defp decode_error_code(0b0_0110), do: {:ok, :data_class_not_implemented}
  defp decode_error_code(0b0_0111), do: {:ok, :data_size_not_implemented}
  defp decode_error_code(0b0_1000), do: {:error, {:reserved, 0b0_1000}}
  defp decode_error_code(0b0_1001), do: {:error, {:reserved, 0b0_1001}}
  # VIF errors
  defp decode_error_code(0b0_1010), do: {:error, {:reserved, 0b0_1010}}
  defp decode_error_code(0b0_1011), do: {:ok, :too_many_vifes}
  defp decode_error_code(0b0_1100), do: {:ok, :illegal_vif_group}
  defp decode_error_code(0b0_1101), do: {:ok, :illegal_vif_exponent}
  defp decode_error_code(0b0_1111), do: {:ok, :unimplemented_action}
  defp decode_error_code(n) when n >= 0b1_0000 and n <= 0b1_0100, do: raise "error code #{n} not used for record errors"
  # Data errors
  defp decode_error_code(0b1_0101), do: {:ok, :no_data_available}
  defp decode_error_code(0b1_0110), do: {:ok, :data_overflow}
  defp decode_error_code(0b1_0111), do: {:ok, :data_underflow}
  defp decode_error_code(0b1_1000), do: {:ok, :data_error}
  defp decode_error_code(n) when n >= 0b1_1001 and n <= 0b1_1011, do: {:error, {:reserved, n}}
  # Other errors
  defp decode_error_code(0b1_1100), do: {:ok, :premature_end_of_record}




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

  ###
  # primary VIF table decoding
  ###
  def decode_vif(:main, _dib, <<_::1, 0b0000::4,  n::3>>),  do: %VIB{description: :energy,             multiplier: pow10to(n-3), unit: "Wh"}
  def decode_vif(:main, _dib, <<_::1, 0b0001::4,  n::3>>),  do: %VIB{description: :energy,             multiplier: pow10to(n),   unit: "J"}
  def decode_vif(:main, _dib, <<_::1, 0b0010::4,  n::3>>),  do: %VIB{description: :volume,             multiplier: pow10to(n-6), unit: "m^3"}
  def decode_vif(:main, _dib, <<_::1, 0b0011::4,  n::3>>),  do: %VIB{description: :mass,               multiplier: pow10to(n-6), unit: "kg"}
  def decode_vif(:main, _dib, <<_::1, 0b01000::5, n::2>>),  do: %VIB{description: :on_time,         unit:  on_time_unit(n)} # how long has the meter been powere
  def decode_vif(:main, _dib, <<_::1, 0b01001::5, n::2>>),  do: %VIB{description: :operating_time,  unit:  on_time_unit(n)} # how long has the meter been accumulatin
  def decode_vif(:main, _dib, <<_::1, 0b0101::4,  n::3>>),  do: %VIB{description: :power,              multiplier: pow10to(n-3), unit: "W"}
  def decode_vif(:main, _dib, <<_::1, 0b0110::4,  n::3>>),  do: %VIB{description: :power,              multiplier: pow10to(n),   unit: "J/h"}
  def decode_vif(:main, _dib, <<_::1, 0b0111::4,  n::3>>),  do: %VIB{description: :volume_flow,        multiplier: pow10to(n-6), unit: "m^3/h"}
  def decode_vif(:main, _dib, <<_::1, 0b1000::4,  n::3>>),  do: %VIB{description: :volume_flow_ext,    multiplier: pow10to(n-7), unit: "m^3/min"}
  def decode_vif(:main, _dib, <<_::1, 0b1001::4,  n::3>>),  do: %VIB{description: :volume_flow_ext,    multiplier: pow10to(n-9), unit: "m^3/s"}
  def decode_vif(:main, _dib, <<_::1, 0b1010::4,  n::3>>),  do: %VIB{description: :mass_flow,          multiplier: pow10to(n-3), unit: "kg/h"}
  def decode_vif(:main, _dib, <<_::1, 0b10110::5, n::2>>),  do: %VIB{description: :flow_temperature,   multiplier: pow10to(n-3), unit: "°C"}
  def decode_vif(:main, _dib, <<_::1, 0b10111::5, n::2>>),  do: %VIB{description: :return_temperature, multiplier: pow10to(n-3), unit: "°C"}
  def decode_vif(:main, _dib, <<_::1, 0b11000::5, n::2>>),  do: %VIB{description: :temperature_difference, multiplier: pow10to(n-3), unit: "K"}
  def decode_vif(:main, _dib, <<_::1, 0b11001::5, n::2>>),  do: %VIB{description: :external_temperature,   multiplier: pow10to(n-3), unit: "°C"}
  def decode_vif(:main, _dib, <<_::1, 0b11010::5, n::2>>),  do: %VIB{description: :pressure,               multiplier: pow10to(n-3), unit: "bar"}
  # TYPE: Date and Time
  # - Data field 0b0010, type G
  # - Data field 0b0011, type J
  # - Data field 0b0100, type F
  # - Data field 0b0110, type I
  # - Data field 0b1101, type M (LVAR)
  def decode_vif(:main, %DIB{data_type: :int_or_bin, size: 16}, <<_::1, 0b1101100::7>>), do: %VIB{description: :date, coding: :type_g}
  def decode_vif(:main, %DIB{data_type: :int_or_bin, size: 24}, <<_::1, 0b1101101::7>>), do: %VIB{description: :time, coding: :type_j}
  def decode_vif(:main, %DIB{data_type: :int_or_bin, size: 32}, <<_::1, 0b1101101::7>>), do: %VIB{description: :naive_datetime, coding: :type_f}
  def decode_vif(:main, %DIB{data_type: :int_or_bin, size: 48}, <<_::1, 0b1101101::7>>), do: %VIB{description: :naive_datetime, coding: :type_i}
  def decode_vif(:main, %DIB{data_type: :variable_length     }, <<_::1, 0b1101101::7>>), do: %VIB{description: :datetime, coding: :type_m}

  def decode_vif(:main, _dib, <<_::1, 0b1101110::7>>),      do: %VIB{description: :units_for_hca}
  def decode_vif(:main, _dib, <<_::1, 0b1101111::7>>),      do: {:error, {:reserved, "VIF 0b1101111 reserved for future use"}}
  def decode_vif(:main, _dib, <<_::1, 0b11100::5, nn::2>>), do: %VIB{description: :averaging_duration, unit: on_time_unit(nn)}
  def decode_vif(:main, _dib, <<_::1, 0b11101::5, nn::2>>), do: %VIB{description: :actuality_duration, unit: on_time_unit(nn)}
  def decode_vif(:main, _dib, <<_::1, 0b1111000::7>>),      do: %VIB{description: :fabrication_no}
  def decode_vif(:main, _dib, <<_::1, 0b1111001::7>>),      do: %VIB{description: :enhanced_identification}
  def decode_vif(:main, _dib, <<_::1, 0b1111010::7>>),      do: %VIB{description: :address}

  ##
  ## The FD table
  ##
  # Currency, not implemented
  def decode_vif(0xFD, _dib, <<_::1, 0b000_00::5, _nn::2>>), do: raise "0xFD vif 0bE00000nn not supported. Credit of 10^(nn–3) of the nominal local legal currency units."
  def decode_vif(0xFD, _dib, <<_::1, 0b000_01::5, _nn::2>>), do: raise "0xFD vif 0bE00000nn not supported. Debit of 10^(nn–3) of the nominal local legal currency units."
  def decode_vif(0xFD, dib, <<_::1, 0b000_1000::7>>), do: %VIB{coding: fd_remark_k(dib), description: :unique_message_identification}
  def decode_vif(0xFD, dib, <<_::1, 0b000_1001::7>>), do: %VIB{coding: fd_remark_k(dib), description: :device_type}
  def decode_vif(0xFD, dib, <<_::1, 0b000_1010::7>>), do: %VIB{coding: fd_remark_k(dib), description: :manufacturer}
  def decode_vif(0xFD, dib, <<_::1, 0b000_1011::7>>), do: %VIB{coding: fd_remark_k(dib), description: :parameter_set_identification}
  def decode_vif(0xFD, dib, <<_::1, 0b000_1100::7>>), do: %VIB{coding: fd_remark_k(dib), description: :model_version}
  def decode_vif(0xFD, dib, <<_::1, 0b000_1101::7>>), do: %VIB{coding: fd_remark_k(dib), description: :hardware_version_number}
  def decode_vif(0xFD, dib, <<_::1, 0b000_1110::7>>), do: %VIB{coding: fd_remark_k(dib), description: :firmware_version_number}
  def decode_vif(0xFD, dib, <<_::1, 0b000_1111::7>>), do: %VIB{coding: fd_remark_k(dib), description: :other_software_version_number}
  def decode_vif(0xFD, dib, <<_::1, 0b001_0000::7>>), do: %VIB{coding: fd_remark_k(dib), description: :customer_location}
  def decode_vif(0xFD, dib, <<_::1, 0b001_0001::7>>), do: %VIB{coding: fd_remark_k(dib), description: :customer}
  def decode_vif(0xFD, dib, <<_::1, 0b001_0010::7>>), do: %VIB{coding: fd_remark_k(dib), description: :access_code_user}
  def decode_vif(0xFD, dib, <<_::1, 0b001_0011::7>>), do: %VIB{coding: fd_remark_k(dib), description: :access_code_operator}
  def decode_vif(0xFD, dib, <<_::1, 0b001_0100::7>>), do: %VIB{coding: fd_remark_k(dib), description: :access_code_system_operator}
  def decode_vif(0xFD, dib, <<_::1, 0b001_0101::7>>), do: %VIB{coding: fd_remark_k(dib), description: :access_code_developer}
  def decode_vif(0xFD, dib, <<_::1, 0b001_0110::7>>), do: %VIB{coding: fd_remark_k(dib), description: :password}
  def decode_vif(0xFD, _dib, <<_::1, 0b001_0111::7>>), do: %VIB{coding: :type_d, description: :error_flags}
  def decode_vif(0xFD, dib, <<_::1, 0b001_1000::7>>), do: %VIB{coding: fd_remark_k(dib), description: :error_mask}
  def decode_vif(0xFD, dib, <<_::1, 0b001_1001::7>>), do: %VIB{coding: fd_remark_k(dib), description: :security_key}
  def decode_vif(0xFD, dib, <<_::1, 0b001_1010::7>>), do: %VIB{coding: fd_remark_k(dib), description: :digital_output}
  def decode_vif(0xFD, dib, <<_::1, 0b001_1011::7>>), do: %VIB{coding: fd_remark_k(dib), description: :digital_input}
  def decode_vif(0xFD, dib, <<_::1, 0b001_1100::7>>), do: %VIB{coding: fd_remark_k(dib), description: :baud_rate}
  def decode_vif(0xFD, dib, <<_::1, 0b001_1101::7>>), do: %VIB{coding: fd_remark_k(dib), description: :response_delay_time}
  def decode_vif(0xFD, _dib, <<_::1, 0b001_1110::7>>), do: %VIB{description: :retry}
  def decode_vif(0xFD, _dib, <<_::1, 0b001_1111::7>>), do: %VIB{description: :remote_control}
  def decode_vif(0xFD, dib, <<_::1, 0b010_0000::7>>), do: %VIB{coding: fd_remark_k(dib), description: :first_storage_number_for_cyclic_storage}
  def decode_vif(0xFD, dib, <<_::1, 0b010_0001::7>>), do: %VIB{coding: fd_remark_k(dib), description: :last_storage_number_for_cyclic_storage}
  def decode_vif(0xFD, dib, <<_::1, 0b010_0010::7>>), do: %VIB{coding: fd_remark_k(dib), description: :size_of_storage_block}
  def decode_vif(0xFD, dib, <<_::1, 0b010_0011::7>>), do: %VIB{coding: fd_remark_k(dib), description: :descriptor_for_tariff_and_device}
  def decode_vif(0xFD, _dib, <<_::1, 0b010_01::5, nn::2>>), do: %VIB{description: :storage_interval, unit: on_time_unit(nn)}
  def decode_vif(0xFD, _dib, <<_::1, 0b010_1000::7>>), do: %VIB{description: {:storage_interval, :month}}
  def decode_vif(0xFD, _dib, <<_::1, 0b010_1001::7>>), do: %VIB{description: {:storage_interval, :year}}
  def decode_vif(0xFD, _dib, <<_::1, 0b010_1010::7>>), do: %VIB{description: :operator_specific_data}
  def decode_vif(0xFD, dib, <<_::1, 0b010_1011::7>>), do: %VIB{coding: fd_remark_k(dib), description: :time_point_second}
  # ... skipped some vifs ...
  def decode_vif(0xFD, _dib, <<_::1, 0b011_1010::7>>), do: %VIB{description: :dimensionless}
  def decode_vif(0xFD, _dib, <<_::1, 0b011_1011::7>>), do: %VIB{description: {:container, :wmbus}}
  def decode_vif(0xFD, dib, <<_::1, 0b011_11::5, nn::2>>), do: %VIB{coding: fd_remark_k(dib), description: :period_of_nominal_data_transmissions, unit: on_time_unit(nn)}
  # ... skipped some vifs ...
  def decode_vif(0xFD, _dib, <<_::1, 0b110_0000::7>>), do: %VIB{description: :reset_counter}
  def decode_vif(0xFD, _dib, <<_::1, 0b110_0001::7>>), do: %VIB{description: :cumulation_counter}
  # ... skipped some vifs ...
  def decode_vif(0xFD, _dib, <<_::1, 0b111_0001::7>>), do: %VIB{description: :rf_level_units_dbm}
  # ... skipped some vifs ...
  def decode_vif(0xFD, dib, <<_::1, 0b111_0100::7>>), do: %VIB{coding: fd_remark_k(dib), description: :remaining_battery_life_time_days}
  def decode_vif(0xFD, dib, <<_::1, 0b111_0101::7>>), do: %VIB{coding: fd_remark_k(dib), description: :number_of_times_meter_was_stopped}
  def decode_vif(0xFD, _dib, <<_::1, 0b111_0110::7>>), do: %VIB{description: {:container, :manufacturer}}
  # ... skipped some vifs ...
  def decode_vif(0xFD, dib, <<vif>>) do
    raise "decoding from VIF linear extension table 0xFD not implemented. VIFE was: #{Exmbus.Debug.u8_to_binary_str(vif)}, DIB was: #{inspect dib}"
  end

  # Table 0xFB from table 14 in EN 13757-3:2018 section 6.4.5
  def decode_vif(0xFB, _dib, <<_::1, 0b000000::6, n::1>>),  do: %VIB{description: :energy, multiplier: pow10to(n-1), unit: "MWh"}
  def decode_vif(0xFB, _dib, <<_::1, 0b000001::6, n::1>>),  do: %VIB{description: :reactive_energy, multiplier: pow10to(n), unit: "kvarh"}
  def decode_vif(0xFB, _dib, <<_::1, 0b000010::6, n::1>>),  do: %VIB{description: :apparent_energy, multiplier: pow10to(n), unit: "kVAh"}
  def decode_vif(0xFB, _dib, <<_::1, 0b000011::6, _::1>>),  do: {:error, {:reserved, "VIF E000011n reserved"}}
  def decode_vif(0xFB, _dib, <<_::1, 0b000100::6, n::1>>),  do: %VIB{description: :energy, multiplier: pow10to(n-1), unit: "GJ"}
  def decode_vif(0xFB, _dib, <<_::1, 0b000101::6, _::1>>),  do: {:error, {:reserved, "VIF E000101n reserved"}}
  def decode_vif(0xFB, _dib, <<_::1, 0b00011::5, nn::2>>),  do: %VIB{description: :energy, multiplier: pow10to(nn-1), unit: "MCal"}
  def decode_vif(0xFB, _dib, <<_::1, 0b001000::6, n::1>>),  do: %VIB{description: :volume, multiplier: pow10to(n+2), unit: "m^3"}
  def decode_vif(0xFB, _dib, <<_::1, 0b001001::6, _::1>>),  do: {:error, {:reserved, "VIF E001001n reserved"}}
  def decode_vif(0xFB, _dib, <<_::1, 0b00101::5, nn::2>>),  do: %VIB{description: :reactive_power, multiplier: pow10to(nn-3), unit: "kVAR"}
  def decode_vif(0xFB, dib, <<_::1, 0b001100::6, n::1>>),  do: %VIB{coding: fb_remark_d(dib), description: :mass, multiplier: pow10to(n+2), unit: "t"}
  def decode_vif(0xFB, dib, <<_::1, 0b001101::6, n::1>>),  do: %VIB{coding: fb_remark_d(dib), description: :relative_humidity, multiplier: pow10to(n-1), unit: "%"}
  def decode_vif(0xFB, _dib, <<_::1, n::7>>) when n >= 0b001_1100 and n <= 0b001_1111, do: {:error, {:reserved, "VIF E0011100 - E0011111 reserved"}}
  def decode_vif(0xFB, _dib, <<_::1, 0b0100000::7>>),  do: %VIB{description: :volume, unit: "ft^3"}
  def decode_vif(0xFB, _dib, <<_::1, 0b0100001::7>>),  do: %VIB{description: :volume, multiplier: 0.1, unit: "ft^3"}
  def decode_vif(0xFB, _dib, <<_::1, n::7>>) when n >= 0b010_0010 and n <= 0b010_0111, do: {:error, {:reserved, "VIF E0100010 - E0100111 were used until 2004, now they are reserved for future use."}}
  def decode_vif(0xFB, _dib, <<_::1, 0b010100::6, n::1>>),  do: %VIB{description: :power, multiplier: pow10to(n-1), unit: "MW"}
  def decode_vif(0xFB, _dib, <<_::1, 0b0101010::7>>),  do: %VIB{description: :phase_volt_to_volt, unit: "°"}
  def decode_vif(0xFB, _dib, <<_::1, 0b0101011::7>>),  do: %VIB{description: :phase_volt_to_current, unit: "°"}
  def decode_vif(0xFB, _dib, <<_::1, 0b01011::5, nn::2>>),  do: %VIB{description: :frequency, multiplier: pow10to(nn-3), unit: "Hz"}
  def decode_vif(0xFB, _dib, <<_::1, 0b011000::6, n::1>>),  do: %VIB{description: :power, multiplier: pow10to(n-1), unit: "GJ/h"}
  def decode_vif(0xFB, _dib, <<_::1, 0b011001::6, _::1>>),  do: {:error, {:reserved, "VIF E011001n reserved"}}
  def decode_vif(0xFB, _dib, <<_::1, 0b01101::5, nn::2>>),  do: %VIB{description: :apparent_power, multiplier: pow10to(nn-3), unit: "kVA"}
  def decode_vif(0xFB, _dib, <<_::1, n::7>>) when n >= 0b0111000 and n <= 0b1010111, do: {:error, {:reserved, "E0111000 - E1010111 reserved"}}
  def decode_vif(0xFB, _dib, <<_::1, n::7>>) when n >= 0b010_0010 and n <= 0b010_0111, do: {:error, {:reserved, "VIF E1011000 - E1100111 were used until 2004, now they are reserved for future use."}}
  def decode_vif(0xFB, _dib, <<_::1, 0b11101::5, nn::2>>),  do: %VIB{description: :temperature_limit, multiplier: pow10to(nn-3), unit: "°C"}
  def decode_vif(0xFB, _dib, <<_::1, 0b1111::4, nnn::3>>),  do: %VIB{description: :cumulative_max_active_power, multiplier: pow10to(nnn-3), unit: "W"}
  def decode_vif(0xFB, dib, <<_::1, 0b1101000::7>>),  do: %VIB{coding: fb_remark_d(dib), description: :resulting_rating_factor_k, multiplier: pow2to(-12), unit: "units for HCA"}
  def decode_vif(0xFB, dib, <<_::1, 0b1101001::7>>),  do: %VIB{coding: fb_remark_d(dib), description: :thermal_output_rating_factor_kq, multiplier: pow2to(-12), unit: "W"}
  # skipping some HCA things here


  def decode_vif(0xFB, dib, <<vif>>) do
    raise "decoding from VIF linear extension table 0xFB not implemented. VIFE was: #{Exmbus.Debug.u8_to_binary_str(vif)}, DIB was: #{inspect dib}"
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
  defp fd_remark_k(%DIB{data_type: :int_or_bin}) do
    :type_c
  end
  defp fd_remark_k(%DIB{data_type: :variable_length}) do
    nil # lvar coding is determined by the lvar
  end
  defp fd_remark_k(%DIB{data_type: :bcd}) do
    :type_a
  end

  defp fb_remark_d(dib) do
    fd_remark_k(dib)
  end

  defp on_time_unit(0b00), do: "seconds"
  defp on_time_unit(0b01), do: "minutes"
  defp on_time_unit(0b10), do: "hours"
  defp on_time_unit(0b11), do: "days"

end
