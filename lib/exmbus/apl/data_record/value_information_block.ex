defmodule Exmbus.Apl.DataRecord.ValueInformationBlock do
  @moduledoc """
  The Value Information Block utilities
  """

  alias Exmbus.Apl.DataRecord.Header

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
  def decode_vif_table(header, :main, <<_::1, 0b0000::4,  n::3>>),  do: {:ok, %{header | description: :energy,             multiplier: pow10to(n-3), unit: "Wh"}}
  def decode_vif_table(header, :main, <<_::1, 0b0001::4,  n::3>>),  do: {:ok, %{header | description: :energy,             multiplier: pow10to(n),   unit: "kJ"}}
  def decode_vif_table(header, :main, <<_::1, 0b0010::4,  n::3>>),  do: {:ok, %{header | description: :volume,             multiplier: pow10to(n-6), unit: "l"}}
  def decode_vif_table(header, :main, <<_::1, 0b0011::4,  n::3>>),  do: {:ok, %{header | description: :mass,               multiplier: pow10to(n-6), unit: "kg"}}
  def decode_vif_table(header, :main, <<_::1, 0b01000::5, n::2>>),  do: {:ok, %{header | description: :on_time,         unit:  on_time_unit(n)}} # how long has the meter been powere}
  def decode_vif_table(header, :main, <<_::1, 0b01001::5, n::2>>),  do: {:ok, %{header | description: :operating_time,  unit:  on_time_unit(n)}} # how long has the meter been accumulatin}
  def decode_vif_table(header, :main, <<_::1, 0b0101::4,  n::3>>),  do: {:ok, %{header | description: :energy,             multiplier: pow10to(n-3), unit: "W"}}
  def decode_vif_table(header, :main, <<_::1, 0b0110::4,  n::3>>),  do: {:ok, %{header | description: :energy,             multiplier: pow10to(n),   unit: "kJ/h"}}
  def decode_vif_table(header, :main, <<_::1, 0b0111::4,  n::3>>),  do: {:ok, %{header | description: :volume_flow,        multiplier: pow10to(n-6), unit: "l/h"}}
  def decode_vif_table(header, :main, <<_::1, 0b1000::4,  n::3>>),  do: {:ok, %{header | description: :volume_flow_ext,    multiplier: pow10to(n-7), unit: "l/min"}}
  def decode_vif_table(header, :main, <<_::1, 0b1001::4,  n::3>>),  do: {:ok, %{header | description: :volume_flow_ext,    multiplier: pow10to(n-9), unit: "ml/s"}}
  def decode_vif_table(header, :main, <<_::1, 0b1010::4,  n::3>>),  do: {:ok, %{header | description: :mass_flow,          multiplier: pow10to(n-3), unit: "kg/h"}}
  def decode_vif_table(header, :main, <<_::1, 0b10110::5, n::2>>),  do: {:ok, %{header | description: :flow_temperature,   multiplier: pow10to(n-3), unit: "°C"}}
  def decode_vif_table(header, :main, <<_::1, 0b10111::5, n::2>>),  do: {:ok, %{header | description: :return_temperature, multiplier: pow10to(n-3), unit: "°C"}}
  def decode_vif_table(header, :main, <<_::1, 0b11000::5, n::2>>),  do: {:ok, %{header | description: :temperature_difference, multiplier: pow10to(n-3), unit: "mK"}}
  def decode_vif_table(header, :main, <<_::1, 0b11001::5, n::2>>),  do: {:ok, %{header | description: :external_temperature,   multiplier: pow10to(n-3), unit: "°C"}}
  def decode_vif_table(header, :main, <<_::1, 0b11010::5, n::2>>),  do: {:ok, %{header | description: :pressure,               multiplier: pow10to(n-3), unit: "mbar"}}
  # TYPE: Date and Time
  # - Data field 0b0010, type G
  # - Data field 0b0011, type J
  # - Data field 0b0100, type F
  # - Data field 0b0110, type I
  # - Data field 0b1101, type M (LVAR)
  def decode_vif_table(%Header{coding: :int_or_bin, size: 16}=header, :main, <<_::1, 0b1101100::7>>),      do: {:ok, %{header | description: :date, data_type: :type_g}}
  def decode_vif_table(%Header{coding: :int_or_bin, size: 24}=header, :main, <<_::1, 0b1101101::7>>),      do: {:ok, %{header | description: :time, data_type: :type_j}}
  def decode_vif_table(%Header{coding: :int_or_bin, size: 32}=header, :main, <<_::1, 0b1101101::7>>),      do: {:ok, %{header | description: :naive_datetime, data_type: :type_f}}
  def decode_vif_table(%Header{coding: :int_or_bin, size: 48}=header, :main, <<_::1, 0b1101101::7>>),      do: {:ok, %{header | description: :naive_datetime, data_type: :type_i}}
  def decode_vif_table(%Header{coding: :variable_length, size: :lvar}=header, :main, <<_::1, 0b1101101::7>>),      do: {:ok, %{header | description: :datetime, data_type: :type_m}}

  def decode_vif_table(header, :main, <<_::1, 0b1101110::7>>),      do: {:ok, %{header | description: :units_for_hca}}
  def decode_vif_table(_header, :main, <<_::1, 0b1101111::7>>),      do: {:error, {:reserved, "VIF 0b1101111 reserved for future use"}}
  def decode_vif_table(header, :main, <<_::1, 0b11100::5, nn::2>>), do: {:ok, %{header | description: :averaging_duration, unit: on_time_unit(nn)}}
  def decode_vif_table(header, :main, <<_::1, 0b11101::5, nn::2>>), do: {:ok, %{header | description: :actuality_duration, unit: on_time_unit(nn)}}
  def decode_vif_table(header, :main, <<_::1, 0b1111000::7>>),      do: {:ok, %{header | description: :fabrication_no}}
  def decode_vif_table(header, :main, <<_::1, 0b1111001::7>>),      do: {:ok, %{header | description: :enhanced_identification}}
  def decode_vif_table(header, :main, <<_::1, 0b1111010::7>>),      do: {:ok, %{header | description: :address}}

  ##
  ## The FD table
  ##
  # Currency, not implemented
  def decode_vif_table(header, 0xFD, <<_::1, 0b000_00::5, nn::2>>), do: raise "0xFD vif 0bE00000nn not supported. Credit of 10^(nn–3) of the nominal local legal currency units."
  def decode_vif_table(header, 0xFD, <<_::1, 0b000_01::5, nn::2>>), do: raise "0xFD vif 0bE00000nn not supported. Debit of 10^(nn–3) of the nominal local legal currency units."
  def decode_vif_table(header, 0xFD, <<_::1, 0b000_1000::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :unique_message_identification}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b000_1001::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :device_type}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b000_1010::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :manufacturer}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b000_1011::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :parameter_set_identification}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b000_1100::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :model_version}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b000_1101::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :hardware_version_number}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b000_1110::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :firmware_version_number}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b000_1111::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :other_software_version_number}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b001_0000::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :customer_location}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b001_0001::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :customer}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b001_0010::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :access_code_user}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b001_0011::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :access_code_operator}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b001_0100::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :access_code_system_operator}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b001_0101::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :access_code_developer}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b001_0110::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :password}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b001_0111::7>>), do: {:ok, %{header | data_type: :type_d, description: :error_flags}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b001_1000::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :error_mask}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b001_1001::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :security_key}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b001_1010::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :digital_output}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b001_1011::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :digital_input}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b001_1100::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :baud_rate}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b001_1101::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :response_delay_time}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b001_1110::7>>), do: {:ok, %{header | description: :retry}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b001_1111::7>>), do: {:ok, %{header | description: :remote_control}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b010_0000::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :first_storage_number_for_cyclic_storage}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b010_0001::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :last_storage_number_for_cyclic_storage}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b010_0010::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :size_of_storage_block}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b010_0011::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :descriptor_for_tariff_and_device}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b010_01::5, nn::2>>), do: {:ok, %{header | description: :storage_interval, unit: on_time_unit(nn)}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b010_1000::7>>), do: {:ok, %{header | description: {:storage_interval, :month}}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b010_1001::7>>), do: {:ok, %{header | description: {:storage_interval, :year}}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b010_1010::7>>), do: {:ok, %{header | description: :operator_specific_data}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b010_1011::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :time_point_second}}
  # ... skipped some vifs ...
  def decode_vif_table(header, 0xFD, <<_::1, 0b011_1010::7>>), do: {:ok, %{header | description: :dimensionless}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b011_1011::7>>), do: {:ok, %{header | description: {:container, :wmbus}}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b011_11::5, nn::2>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :period_of_nominal_data_transmissions, unit: on_time_unit(nn)}}
  # ... skipped some vifs ...
  def decode_vif_table(header, 0xFD, <<_::1, 0b110_0000::7>>), do: {:ok, %{header | description: :reset_counter}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b110_0001::7>>), do: {:ok, %{header | description: :cumulation_counter}}
  # ... skipped some vifs ...
  def decode_vif_table(header, 0xFD, <<_::1, 0b111_0001::7>>), do: {:ok, %{header | description: :rf_level_units_dbm}}
  # ... skipped some vifs ...
  def decode_vif_table(header, 0xFD, <<_::1, 0b111_0100::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :remaining_battery_life_time_days}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b111_0101::7>>), do: {:ok, %{header | data_type: fd_remark_k(header), description: :number_of_times_meter_was_stopped}}
  def decode_vif_table(header, 0xFD, <<_::1, 0b111_0110::7>>), do: {:ok, %{header | description: {:container, :manufacturer}}}
  # ... skipped some vifs ...
  def decode_vif_table(header, 0xFD, <<vif>>) do
    raise "decoding from VIF linear extension table 0xFD not implemented. VIFE was: #{Exmbus.Debug.u8_to_binary_str(vif)}, header was: #{inspect header}"
  end

  # TODO 0xFB table
  # def decode_vif_table(header, 0xFB, <<_::1, 0b000_0000::7>>), do: {}
  # def decode_vif_table(header, 0xFB, <<_::1, 0b000_0000::7>>), do: {}
  def decode_vif_table(header, 0xFB, <<vif>>) do
    raise "decoding from VIF linear extension table 0xFB not implemented. VIFE was: #{Exmbus.Debug.u8_to_binary_str(vif)}, header was: #{inspect header}"
  end

  # This function implements remark K in table 12 which says:
  # "Binary data (see Table 4) shall be interpreted as data type A (unsigned BCD) or data type C (unsigned integer) according to Annex A."
  # I read this as: if the coding is :int_or_bin then decode it as either type A or type C, but it isn't clear
  # to me when to do A and when to do C.
  # Maybe what it SHOULD have set is that if the coding is int/binary then do type C, if it's BCD then do type A.
  # Or maybe it says that the binary (as in the raw) data should be decoded as either BCD or UINT, and
  # anything else is an error, but that also seems weird for something like manufacturer, customer, etc.
  defp fd_remark_k(%Header{data_type: :type_b}) do
    :type_c # possibly this?
  end
  defp fd_remark_k(%Header{}=header) do
    raise "TODO Not sure what the coding should be but header was #{inspect header}"
  end

  defp on_time_unit(0b00), do: "seconds"
  defp on_time_unit(0b01), do: "minutes"
  defp on_time_unit(0b10), do: "hours"
  defp on_time_unit(0b11), do: "days"

end
