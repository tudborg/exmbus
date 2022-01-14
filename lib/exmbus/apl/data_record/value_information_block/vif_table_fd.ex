defmodule Exmbus.Apl.DataRecord.ValueInformationBlock.VifTableFD do

  alias Exmbus.Apl.DataRecord.DataInformationBlock, as: DIB
  alias Exmbus.Apl.DataRecord.ValueInformationBlock, as: VIB
  alias Exmbus.Apl.DataRecord.ValueInformationBlock.Vife

  ##
  ## The FD table
  ##
  def parse(<<_::1, 0b000_00::5, _nn::2>>, _opts, _ctx), do: raise "0xFD vif 0bE00000nn not supported. Credit of 10^(nn–3) of the nominal local legal currency units."
  def parse(<<_::1, 0b000_01::5, _nn::2>>, _opts, _ctx), do: raise "0xFD vif 0bE00000nn not supported. Debit of 10^(nn–3) of the nominal local legal currency units."
  def parse(<<e::1, 0b000_1000::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :unique_message_identification} | ctx])
  def parse(<<e::1, 0b000_1001::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :device_type} | ctx])
  def parse(<<e::1, 0b000_1010::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :manufacturer} | ctx])
  def parse(<<e::1, 0b000_1011::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :parameter_set_identification} | ctx])
  def parse(<<e::1, 0b000_1100::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :model_version} | ctx])
  def parse(<<e::1, 0b000_1101::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :hardware_version_number} | ctx])
  def parse(<<e::1, 0b000_1110::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :firmware_version_number} | ctx])
  def parse(<<e::1, 0b000_1111::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :other_software_version_number} | ctx])
  def parse(<<e::1, 0b001_0000::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :customer_location} | ctx])
  def parse(<<e::1, 0b001_0001::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :customer} | ctx])
  def parse(<<e::1, 0b001_0010::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :access_code_user} | ctx])
  def parse(<<e::1, 0b001_0011::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :access_code_operator} | ctx])
  def parse(<<e::1, 0b001_0100::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :access_code_system_operator} | ctx])
  def parse(<<e::1, 0b001_0101::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :access_code_developer} | ctx])
  def parse(<<e::1, 0b001_0110::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :password} | ctx])
  def parse(<<e::1, 0b001_0111::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: :type_d, description: :error_flags} | ctx])
  def parse(<<e::1, 0b001_1000::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :error_mask} | ctx])
  def parse(<<e::1, 0b001_1001::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :security_key} | ctx])
  def parse(<<e::1, 0b001_1010::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :digital_output} | ctx])
  def parse(<<e::1, 0b001_1011::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :digital_input} | ctx])
  def parse(<<e::1, 0b001_1100::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :baud_rate} | ctx])
  def parse(<<e::1, 0b001_1101::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :response_delay_time} | ctx])
  def parse(<<e::1, 0b001_1110::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, description: :retry} | ctx])
  def parse(<<e::1, 0b001_1111::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, description: :remote_control} | ctx])
  def parse(<<e::1, 0b010_0000::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :first_storage_number_for_cyclic_storage} | ctx])
  def parse(<<e::1, 0b010_0001::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :last_storage_number_for_cyclic_storage} | ctx])
  def parse(<<e::1, 0b010_0010::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :size_of_storage_block} | ctx])
  def parse(<<e::1, 0b010_0011::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :descriptor_for_tariff_and_device} | ctx])
  def parse(<<e::1, 0b010_01::5, nn::2, rest::binary>>, opts, ctx), do: Vife.parse(e, rest, opts, [%VIB{table: :fd, description: :storage_interval, unit: on_time_unit(nn)} | ctx])
  def parse(<<e::1, 0b010_1000::7, rest::binary>>, opts,      ctx), do: Vife.parse(e, rest, opts, [%VIB{table: :fd, description: {:storage_interval, :month}} | ctx])
  def parse(<<e::1, 0b010_1001::7, rest::binary>>, opts,      ctx), do: Vife.parse(e, rest, opts, [%VIB{table: :fd, description: {:storage_interval, :year}} | ctx])
  def parse(<<e::1, 0b010_1010::7, rest::binary>>, opts,      ctx), do: Vife.parse(e, rest, opts, [%VIB{table: :fd, description: :operator_specific_data} | ctx])
  def parse(<<e::1, 0b010_1011::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :time_point_second} | ctx])
  # ... skipped some vifs ...
  def parse(<<e::1, 0b011_1010::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, description: :dimensionless} | ctx])
  def parse(<<e::1, 0b011_1011::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, description: {:container, :wmbus}} | ctx])
  def parse(<<e::1, 0b011_11::5, nn::2, rest::binary>>, opts, ctx), do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :period_of_nominal_data_transmissions, unit: on_time_unit(nn)} | ctx])
  # ... skipped some vifs ...
  def parse(<<e::1, 0b110_0000::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, description: :reset_counter} | ctx])
  def parse(<<e::1, 0b110_0001::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, description: :cumulation_counter} | ctx])
  # ... skipped some vifs ...
  def parse(<<e::1, 0b111_0001::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, description: :rf_level_units_dbm} | ctx])
  # ... skipped some vifs ...
  def parse(<<e::1, 0b111_0100::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :remaining_battery_life_time_days} | ctx])
  def parse(<<e::1, 0b111_0101::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, coding: fd_remark_k(ctx), description: :number_of_times_meter_was_stopped} | ctx])
  def parse(<<e::1, 0b111_0110::7, rest::binary>>, opts, ctx),      do: Vife.parse(e, rest, opts, [%VIB{table: :fd, description: {:container, :manufacturer}} | ctx])
  # ... skipped some vifs ...
  def parse(<<e::1, vif::7, rest::binary>>, _opts, ctx) do
    raise "decoding from VIF linear extension table 0xFD not implemented. VIFE was: #{Exmbus.Debug.u8_to_hex_str(vif)} (#{Exmbus.Debug.u8_to_binary_str(vif)}), ctx was: #{inspect ctx}, rest was: #{inspect rest}"
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
  defp fd_remark_k([%DIB{data_type: :int_or_bin} | _]) do
    :type_c
  end
  defp fd_remark_k([%DIB{data_type: :variable_length} | _]) do
    nil # lvar coding is determined by the lvar
  end
  defp fd_remark_k([%DIB{data_type: :bcd} | _]) do
    :type_a
  end

  defp on_time_unit(0b00), do: "seconds"
  defp on_time_unit(0b01), do: "minutes"
  defp on_time_unit(0b10), do: "hours"
  defp on_time_unit(0b11), do: "days"

end
