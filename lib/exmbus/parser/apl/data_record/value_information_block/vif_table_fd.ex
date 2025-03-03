defmodule Exmbus.Parser.Apl.DataRecord.ValueInformationBlock.VifTableFD do
  @moduledoc """
  This module implements the VIF extension table FD (0xFD)
  """

  alias Exmbus.Parser.Apl.DataRecord.DataInformationBlock, as: DIB
  alias Exmbus.Parser.Apl.DataRecord.ValueInformationBlock, as: VIB
  alias Exmbus.Parser.Apl.DataRecord.ValueInformationBlock.Vife

  ##
  ## The FD table
  ##
  def parse(<<_::1, 0b000_00::5, _nn::2>>, _ctx), do: raise "0xFD vif 0bE00000nn not supported. Credit of 10^(nn–3) of the nominal local legal currency units."
  def parse(<<_::1, 0b000_01::5, _nn::2>>, _ctx), do: raise "0xFD vif 0bE00000nn not supported. Debit of 10^(nn–3) of the nominal local legal currency units."
  def parse(<<e::1, 0b000_1000::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :unique_message_identification}})
  def parse(<<e::1, 0b000_1001::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :device_type}})
  def parse(<<e::1, 0b000_1010::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :manufacturer}})
  def parse(<<e::1, 0b000_1011::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :parameter_set_identification}})
  def parse(<<e::1, 0b000_1100::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :model_version}})
  def parse(<<e::1, 0b000_1101::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :hardware_version_number}})
  def parse(<<e::1, 0b000_1110::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :firmware_version_number}})
  def parse(<<e::1, 0b000_1111::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :other_software_version_number}})
  def parse(<<e::1, 0b001_0000::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :customer_location}})
  def parse(<<e::1, 0b001_0001::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :customer}})
  def parse(<<e::1, 0b001_0010::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :access_code_user}})
  def parse(<<e::1, 0b001_0011::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :access_code_operator}})
  def parse(<<e::1, 0b001_0100::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :access_code_system_operator}})
  def parse(<<e::1, 0b001_0101::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :access_code_developer}})
  def parse(<<e::1, 0b001_0110::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :password}})
  def parse(<<e::1, 0b001_0111::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: :type_d, description: :error_flags}})
  def parse(<<e::1, 0b001_1000::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :error_mask}})
  def parse(<<e::1, 0b001_1001::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :security_key}})
  def parse(<<e::1, 0b001_1010::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :digital_output}})
  def parse(<<e::1, 0b001_1011::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :digital_input}})
  def parse(<<e::1, 0b001_1100::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :baud_rate}})
  def parse(<<e::1, 0b001_1101::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :response_delay_time}})
  def parse(<<e::1, 0b001_1110::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, description: :retry}})
  def parse(<<e::1, 0b001_1111::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, description: :remote_control}})
  def parse(<<e::1, 0b010_0000::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :first_storage_number_for_cyclic_storage}})
  def parse(<<e::1, 0b010_0001::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :last_storage_number_for_cyclic_storage}})
  def parse(<<e::1, 0b010_0010::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :size_of_storage_block}})
  def parse(<<e::1, 0b010_0011::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :descriptor_for_tariff_and_device}})
  def parse(<<e::1, 0b010_01::5, nn::2, rest::binary>>, ctx), do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, description: :storage_interval, unit: on_time_unit(nn)}})
  def parse(<<e::1, 0b010_1000::7, rest::binary>>,      ctx), do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, description: {:storage_interval, :month}}})
  def parse(<<e::1, 0b010_1001::7, rest::binary>>,      ctx), do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, description: {:storage_interval, :year}}})
  def parse(<<e::1, 0b010_1010::7, rest::binary>>,      ctx), do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, description: :operator_specific_data}})
  def parse(<<e::1, 0b010_1011::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :time_point_second}})
  def parse(<<e::1, 0b010_11::5, 0b00::2, rest::binary>>, ctx), do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: {:duration_size_last_readout, :second}}})
  def parse(<<e::1, 0b010_11::5, 0b01::2, rest::binary>>, ctx), do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: {:duration_size_last_readout, :minute}}})
  def parse(<<e::1, 0b010_11::5, 0b10::2, rest::binary>>, ctx), do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: {:duration_size_last_readout, :hour}}})
  def parse(<<e::1, 0b010_11::5, 0b11::2, rest::binary>>, ctx), do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: {:duration_size_last_readout, :day}}})
  # ... skipped some vifs ...
  def parse(<<e::1, 0b011_1010::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, description: :dimensionless}})
  def parse(<<e::1, 0b011_1011::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, description: {:container, :wmbus}}})
  def parse(<<e::1, 0b011_11::5, nn::2, rest::binary>>, ctx), do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :period_of_nominal_data_transmissions, unit: on_time_unit(nn)}})
  def parse(<<e::1, 0b100::3, nnnn::4, rest::binary>>, ctx),  do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, description: :volts, multiplier: pow10to(nnnn-9), unit: "V"}})
  def parse(<<e::1, 0b101::3, nnnn::4, rest::binary>>, ctx),  do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, description: :amperes, multiplier: pow10to(nnnn-12), unit: "A"}})
  # ... skipped some vifs ...
  def parse(<<e::1, 0b110_0000::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, description: :reset_counter}})
  def parse(<<e::1, 0b110_0001::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, description: :cumulation_counter}})
  # ... skipped some vifs ...
  def parse(<<e::1, 0b111_0001::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, description: :rf_level_units_dbm}})
  # ... skipped some vifs ...
  def parse(<<e::1, 0b111_0100::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :remaining_battery_life_time_days}})
  def parse(<<e::1, 0b111_0101::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, coding: fd_remark_k(ctx), description: :number_of_times_meter_was_stopped}})
  def parse(<<e::1, 0b111_0110::7, rest::binary>>, ctx),      do: Vife.parse(e, rest, %{ctx | vib: %VIB{table: :fd, description: {:container, :manufacturer}}})
  # ... skipped some vifs ...
  def parse(<<_::1, vif::7, rest::binary>>, ctx) do
    raise "decoding from VIF linear extension table 0xFD not implemented. VIFE was: #{Exmbus.Debug.to_hex(vif)} (#{Exmbus.Debug.to_bits(vif)}), ctx was: #{inspect ctx}, rest was: #{inspect rest}"
  end


  # TODO: Try to understand this remark k of table 12 (page 19), section is 6.4.4.1
  # NOTE: This is also remark d in table 14 (VIF table 0xFB)
  # This function implements remark K in table 12 which says:
  # "Binary data (see Table 4) shall be interpreted as data type A (unsigned BCD) or data type C (unsigned integer) according to Annex A."
  # I read this as: if the coding is :int_or_bin then decode it as either type A or type C, but it isn't clear
  # to me when to do A and when to do C.
  # Maybe what it SHOULD have set is that if the coding is int/binary then do type C, if it's BCD then do type A.
  # Or maybe it says that the binary (as in the raw) data should be decoded as either BCD or UINT, and
  # anything else is an error, but that also seems weird for something like manufacturer, customer, etc.
  defp fd_remark_k(%{dib: %DIB{data_type: :int_or_bin}}) do
    :type_c
  end
  defp fd_remark_k(%{dib: %DIB{data_type: :variable_length}}) do
    nil # lvar coding is determined by the lvar
  end
  defp fd_remark_k(%{dib: %DIB{data_type: :bcd}}) do
    :type_a
  end

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
end
