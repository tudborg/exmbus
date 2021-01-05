defmodule Exmbus.Apl.DataRecord.ValueInformationBlock do
  @moduledoc """
  The Value Information Block.
  Contains the DIF+DIFE
  """

  use Bitwise

  defstruct [
    description: nil, # An atom describing the value. This is an atomized version of the "Description" from the documentation.
    multiplier: nil,  # A multiplier to apply to the data. It's part of the VIF(E) information.
    unit: nil,        # A string giving the unit of the value (e.g. kJ/h or °C)
    extensions: [],   # A list of extensions that might modify the meaning of the data.

    override_data_type: nil, # If set, decode according to this datatype instead of what is found in the DIF
                             # Options are: type_a, type_b, type_c, type_d, type_f, type_g,
                             #              type_h, type_i, type_j, type_k, type_l, type_m
  ]

  @doc """
  Decode VIB (Value Information Block) and return a %ValueInformationBlock{} struct and rest of data.

  There are 5 types of coding depending on the VIF:
  - primary VIF: 0bE000_0000 to 0bE111_1010
  - plain-text VIF: 0bE111_1100
  - linear VIF-extension FD and FB
  - Any VIF: 7E / FE
  - Manufacturer-specific: 7F / FF


    iex> decode(<<0b00000011, 0xFF>>)
    {:ok, %ValueInformationBlock{
      description: :energy,
      multiplier: 1,
      unit: "Wh",
      extensions: [],
    }, <<0xFF>>}

    iex> decode(<<0b0111_1100, 5, 104, 101, 108, 108, 111, 0xFF>>)
    {:ok, %ValueInformationBlock{
      description: :plain_text,
      multiplier: nil, # no multiplier for text
      unit: "hello",
      extensions: [],
    }, <<0xFF>>}

  """
  @spec decode(binary(), [opt :: any()]) :: {:ok, %__MODULE__{}, rest :: binary()}
  def decode(bin, opts \\ []) do
    # collect all the relevant bytes up front for easier parsing.
    # I don't think this is ideal for performance but it's probably Good Enough.
    {vib, rest} = collect_vib(bin)
    # the :main is the default decode table name
    decode_vib(:main, vib, rest, opts)
  end

  # linear VIF-extension: EF, reserved for future use
  defp decode_vib(_table, <<0xEF, _vifes::binary>>, _rest, _opts), do: raise "VIF 0xEF reserved for future use."
  # plain-text VIF:
  defp decode_vib(_table, <<_::1, 0b111_1100::7, vifes::binary>>=vib, <<len, rest::binary>>, opts) do
    # the VIF is len from rest decoded as ASCII (which is "just is" so easy)
    <<plaintext::binary-size(len), rest::binary>> = rest
    decode_vifes(vifes, rest, %__MODULE__{description: :plain_text, unit: plaintext}, opts)
  end
  # Any VIF: 7E / FE
  # This VIF-Code can be used in direction master to slave for readout selection of all VIFs.
  # See special function in 6.3.3
  defp decode_vib(_table, <<_::1, 0b1111110::7, _vifes::binary>>, _rest, _opts) do
    raise "Any VIF 0x7E / 0xFE not implemented. See 6.4.1 list item d."
  end
  # manufacturer specific encoding. All bets are off.
  defp decode_vib(_table, <<_::1, 0b1111111::7, _vifes::binary>>, _rest, _opts) do
    raise "Manufacturer-specific VIF encoding not implemented. See 6.4.1 list item e."
  end
  # linear VIF-extension: 0xFD, decode vif from table 14.
  defp decode_vib(_table, <<0xFD, vifes::binary>>, rest, opts) do
    decode_vib(0xFD, vifes, rest, opts)
  end
  # linear VIF-extension: FB, decode vif from table 12.
  defp decode_vib(_table, <<0xFB, vifes::binary>>, rest, opts) do
    decode_vib(0xFB, vifes, rest, opts)
  end
  defp decode_vib(table, <<vif::binary-size(1), vifes::binary>>, rest, opts) do
    case decode_vif_table(table, vif) do
      {:ok, {override, description, multiplier, unit}} ->
        decode_vifes(vifes, rest, %__MODULE__{
          description: description,
          multiplier: multiplier,
          unit: unit,
          override_data_type: override,
        }, opts)
    end
  end

  # vifes is a list of vife bytes
  # struct is an initialized ValueInformationBlock from previous VIF
  # opts is options from the outside.
  defp decode_vifes(<<>>, rest, struct, _opts) do
    # no more VIFE bytes to decode, return struct and rest
    {:ok, struct, rest}
  end
  defp decode_vifes(<<_::1, 0b000::3, _::4, _vifes::binary>>=vifes, _rest, _struct, _opts) do
    <<vife, _::binary>> = vifes
    raise "VIFE #{u8_to_hex(vife)} reserved for object actions (master to slave) (6.4.7) or for error codes (slave to master) (6.4.8)"
  end
  defp decode_vifes(<<_::1, 0b0010000::7, _vifes::binary>>=vifes, _rest, _struct, _opts) do
    <<vife, _::binary>> = vifes
    raise "VIFE E0010000 (#{u8_to_hex(vife)}) reserved"
  end
  defp decode_vifes(<<_::1, 0b0010001::7, _vifes::binary>>=vifes, _rest, _struct, _opts) do
    <<vife, _::binary>> = vifes
    raise "VIFE E0010001 (#{u8_to_hex(vife)}) reserved"
  end
  defp decode_vifes(<<vife, _vifes::binary>>, _rest, _struct, _opts) do
    raise "VIFE #{u8_to_hex(vife)} not implemented"
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

  ###
  # primary VIF table decoding
  ###
  defp decode_vif_table(:main, <<_::1, 0b0000::4,  n::3>>),  do: {:ok, {nil, :energy, pow10to(n-3), "Wh"}}
  defp decode_vif_table(:main, <<_::1, 0b0001::4,  n::3>>),  do: {:ok, {nil, :energy, pow10to(n), "kJ"}}
  defp decode_vif_table(:main, <<_::1, 0b0010::4,  n::3>>),  do: {:ok, {nil, :volume, pow10to(n-6), "l"}}
  defp decode_vif_table(:main, <<_::1, 0b0011::4,  n::3>>),  do: {:ok, {nil, :mass, pow10to(n-6), "kg"}}
  defp decode_vif_table(:main, <<_::1, 0b01000::5, n::2>>),  do: {:ok, {nil, :on_time, nil, on_time_unit(n)}} # how long has the meter been powered
  defp decode_vif_table(:main, <<_::1, 0b01001::5, n::2>>),  do: {:ok, {nil, :operating_time, nil, on_time_unit(n)}} # how long has the meter been accumulating
  defp decode_vif_table(:main, <<_::1, 0b0101::4,  n::3>>),  do: {:ok, {nil, :energy, pow10to(n-3), "W"}}
  defp decode_vif_table(:main, <<_::1, 0b0110::4,  n::3>>),  do: {:ok, {nil, :energy, pow10to(n), "kJ/h"}}
  defp decode_vif_table(:main, <<_::1, 0b0111::4,  n::3>>),  do: {:ok, {nil, :volume_flow, pow10to(n-6), "l/h"}}
  defp decode_vif_table(:main, <<_::1, 0b1000::4,  n::3>>),  do: {:ok, {nil, :volume_flow_ext, pow10to(n-7), "l/min"}}
  defp decode_vif_table(:main, <<_::1, 0b1001::4,  n::3>>),  do: {:ok, {nil, :volume_flow_ext, pow10to(n-9), "ml/s"}}
  defp decode_vif_table(:main, <<_::1, 0b1010::4,  n::3>>),  do: {:ok, {nil, :mass_flow, pow10to(n-3), "kg/h"}}
  defp decode_vif_table(:main, <<_::1, 0b10110::5, n::2>>),  do: {:ok, {nil, :flow_temperature, pow10to(n-3), "°C"}}
  defp decode_vif_table(:main, <<_::1, 0b10111::5, n::2>>),  do: {:ok, {nil, :return_temperature, pow10to(n-3), "°C"}}
  defp decode_vif_table(:main, <<_::1, 0b11000::5, n::2>>),  do: {:ok, {nil, :temperature_difference, pow10to(n-3), "mK"}}
  defp decode_vif_table(:main, <<_::1, 0b11001::5, n::2>>),  do: {:ok, {nil, :external_temperature, pow10to(n-3), "°C"}}
  defp decode_vif_table(:main, <<_::1, 0b11010::5, n::2>>),  do: {:ok, {nil, :pressure, pow10to(n-3), "mbar"}}
  # Timestamp VIFs. these are annoying because their interpretation depends on the Data Field in the DIF as well.
  # we generalise here, because we can infer the correct data type based on the coding when we decode (the size differs)
  # TYPE: Date. Data field 0b0010, type G
  defp decode_vif_table(:main, <<_::1, 0b1101100::7>>),      do: {:ok, {nil, :date, nil, ""}}
  # TYPE: Date+Time.
  # - Data field 0b0100, type F
  # - Data field 0b0011, type J (only time, but we still just collapse it into :datetime because we can't tell at this point.
  # - Data field 0b0110, type I
  # - Data field 0b1101, type M (LVAR)
  defp decode_vif_table(:main, <<_::1, 0b1101101::7>>),      do: {:ok, {nil, :datetime, nil, ""}}

  defp decode_vif_table(:main, <<_::1, 0b1101110::7>>),      do: {:ok, {nil, :units_for_hca, nil, ""}}
  defp decode_vif_table(:main, <<_::1, 0b1101111::7>>),      do: {:error, {nil, :reserved, "VIF 0b1101111 reserved for future use"}}
  defp decode_vif_table(:main, <<_::1, 0b11100::5, nn::2>>), do: {:ok, {nil, :averaging_duration, nil, on_time_unit(nn)}}
  defp decode_vif_table(:main, <<_::1, 0b11101::5, nn::2>>), do: {:ok, {nil, :actuality_duration, nil, on_time_unit(nn)}}
  defp decode_vif_table(:main, <<_::1, 0b1111000::7>>),      do: {:ok, {nil, :fabrication_no, nil, ""}}
  defp decode_vif_table(:main, <<_::1, 0b1111001::7>>),      do: {:ok, {nil, :enhanced_identification, nil, ""}}
  defp decode_vif_table(:main, <<_::1, 0b1111010::7>>),      do: {:ok, {nil, :address, nil, ""}}

  ##
  ## The FD table
  ##
  # Currency, not implemented
  defp decode_vif_table(0xFD, <<_::1, 0b000_00::5, nn::2>>), do: raise "0xFD vif 0bE00000nn not supported. Credit of 10^(nn–3) of the nominal local legal currency units."
  defp decode_vif_table(0xFD, <<_::1, 0b000_01::5, nn::2>>), do: raise "0xFD vif 0bE00000nn not supported. Debit of 10^(nn–3) of the nominal local legal currency units."
  defp decode_vif_table(0xFD, <<_::1, 0b000_1000::7>>), do: {:ok, {nil, :unique_message_identification, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b000_1001::7>>), do: {:ok, {nil, :device_type, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b000_1010::7>>), do: {:ok, {nil, :manufacturer, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b000_1011::7>>), do: {:ok, {nil, :parameter_set_identification, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b000_1100::7>>), do: {:ok, {nil, :model_version, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b000_1101::7>>), do: {:ok, {nil, :hardware_version_number, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b000_1110::7>>), do: {:ok, {nil, :firmware_version_number, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b000_1111::7>>), do: {:ok, {nil, :other_software_version_number, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b001_0000::7>>), do: {:ok, {nil, :customer_location, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b001_0001::7>>), do: {:ok, {nil, :customer, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b001_0010::7>>), do: {:ok, {nil, :access_code_user, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b001_0011::7>>), do: {:ok, {nil, :access_code_operator, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b001_0100::7>>), do: {:ok, {nil, :access_code_system_operator, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b001_0101::7>>), do: {:ok, {nil, :access_code_developer, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b001_0110::7>>), do: {:ok, {nil, :password, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b001_0111::7>>), do: {:ok, {nil, :error_flags, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b001_1000::7>>), do: {:ok, {nil, :error_mask, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b001_1001::7>>), do: {:ok, {nil, :security_key, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b001_1010::7>>), do: {:ok, {nil, :digital_output, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b001_1011::7>>), do: {:ok, {nil, :digital_input, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b001_1100::7>>), do: {:ok, {nil, :baud_rate, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b001_1101::7>>), do: {:ok, {nil, :response_delay_time, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b001_1110::7>>), do: {:ok, {nil, :retry, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b001_1111::7>>), do: {:ok, {nil, :remote_control, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b010_0000::7>>), do: {:ok, {nil, :first_storage_number_for_cyclic_storage, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b010_0001::7>>), do: {:ok, {nil, :last_storage_number_for_cyclic_storage, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b010_0010::7>>), do: {:ok, {nil, :size_of_storage_block, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b010_0011::7>>), do: {:ok, {nil, :descriptor_for_tariff_and_device, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b010_01::5, 00::2>>), do: {:ok, {nil, {:storage_interval, :second}, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b010_01::5, 01::2>>), do: {:ok, {nil, {:storage_interval, :minute}, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b010_01::5, 10::2>>), do: {:ok, {nil, {:storage_interval, :hour}, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b010_01::5, 11::2>>), do: {:ok, {nil, {:storage_interval, :day}, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b010_1000::7>>), do: {:ok, {nil, {:storage_interval, :month}, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b010_1001::7>>), do: {:ok, {nil, {:storage_interval, :year}, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b010_1010::7>>), do: {:ok, {nil, :operator_specific_data, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b010_1011::7>>), do: {:ok, {nil, :time_point_second, nil, ""}}
  # ... skipped some vifs ...
  defp decode_vif_table(0xFD, <<_::1, 0b011_1010::7>>), do: {:ok, {nil, :dimensionless, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b011_1011::7>>), do: {:ok, {nil, {:container, :wmbus}, nil, ""}}
  # ... skipped some vifs ...
  defp decode_vif_table(0xFD, <<_::1, 0b110_0000::7>>), do: {:ok, {nil, :reset_counter, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b110_0001::7>>), do: {:ok, {nil, :cumulation_counter, nil, ""}}
  # ... skipped some vifs ...
  defp decode_vif_table(0xFD, <<_::1, 0b111_0001::7>>), do: {:ok, {nil, :rf_level_units_dbm, nil, ""}}
  # ... skipped some vifs ...
  defp decode_vif_table(0xFD, <<_::1, 0b111_0100::7>>), do: {:ok, {nil, :remaining_battery_life_time_days, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b111_0101::7>>), do: {:ok, {nil, :number_of_times_meter_was_stopped, nil, ""}}
  defp decode_vif_table(0xFD, <<_::1, 0b111_0110::7>>), do: {:ok, {nil, {:container, :manufacturer}, nil, ""}}
  # ... skipped some vifs ...
  defp decode_vif_table(0xFD, <<vif>>) do
    {:error, {:unknown_vif, "decoding from VIF linear extension table 0xFD not implemented (VIFE was #{u8_to_hex(vif)})"}}
  end

  # TODO 0xFB table
  # defp decode_vif_table(0xFB, <<_::1, 0b000_0000::7>>), do: {}
  # defp decode_vif_table(0xFB, <<_::1, 0b000_0000::7>>), do: {}
  defp decode_vif_table(0xFB, <<vif>>) do
    {:error, {:unknown_vif, "decoding from VIF linear extension table 0xFB not implemented (VIFE was #{u8_to_hex(vif)})"}}
  end

  # collect vif and vife bytes and return them and the rest of the binary.
  # TODO performance? Probably OK.
  @spec collect_vib(binary()) :: {binary(), binary()}
  defp collect_vib(<<byte::binary-size(1), rest::binary>>) do
    case byte do
      <<0::1, _::7>> ->
        {byte, rest}
      <<1::1, _::7>> ->
        {tail, rest} = collect_vib(rest)
        {<<byte::binary, tail::binary>>, rest}
    end
  end

  defp on_time_unit(0b00), do: "seconds"
  defp on_time_unit(0b01), do: "minutes"
  defp on_time_unit(0b10), do: "hours"
  defp on_time_unit(0b11), do: "days"

  defp u8_to_hex(u) when u >= 0 and u <= 255, do: "0x#{Integer.to_string(u, 16)}"
end
