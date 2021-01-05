defmodule Exmbus.Tpl.Device do
  @table [
    {<<0x00>>, :other, "[other]"},
    {<<0x01>>, :oil,   "[oil]"},
    {<<0x02>>, :electricity, "[electricity]"},
    {<<0x03>>, :gas,     "[gas]"},
    {<<0x04>>, :heat,    "[heat]"},
    {<<0x05>>, :steam,   "[steam]"},
    {<<0x06>>, :warm_water, "[warm_water]"},
    {<<0x07>>, :water,      "[water]"},
    {<<0x08>>, :heat_cost_allocator, "[heat_cost_allocator]"},
    {<<0x09>>, :compressed_air,      "[compressed_air]"},
    {<<0x0A>>, :cooling_load_meter_outlet, "[cooling_load_meter_outlet]"},
    {<<0x0B>>, :cooling_load_meter_inlet,  "[cooling_load_meter_inlet]"},
    {<<0x0C>>, :heat_inlet,                "[heat_inlet]"},
    {<<0x0D>>, :heat_cooling_load_meter,   "[heat_cooling_load_meter]"},
    {<<0x0E>>, :bus,         "[bus]"},
    {<<0x0F>>, :unknown,     "[unknown]"},
    {<<0x15>>, :hot_water,   "[hot_water]"},
    {<<0x16>>, :cold_water,  "[cold_water]"},
    #  dual-register hot/cold meter.
    # such a meter registers water flow above a limit temperature
    # in a separate register with an appropriate tariff ID
    {<<0x17>>, :hot_cold_water, "[hot_cold_water]"},
    {<<0x18>>, :pressure,       "[pressure]"},
    {<<0x19>>, :ad_converter,    "[ad_converter]"}
  ]

  @doc """
  decode a device byte into internal atom
  """
  @spec decode(binary) :: atom
  Enum.each(@table, fn ({byte, atom, _}) ->
      def decode(unquote(byte)), do: unquote(atom)
  end)
  @doc """
  encode an internal device atom into it's mbus byte
  """
  @spec encode(atom) :: binary
  Enum.each(@table, fn ({byte, atom, _}) ->
      def encode(unquote(atom)), do: unquote(byte)
  end)
  @doc """
  return a string describing the device (either byte or atom)
  """
  @spec format(atom|binary) :: String.t
  Enum.each(@table, fn ({byte, atom, description}) ->
      def format(unquote(byte)), do: unquote(description)
      def format(unquote(atom)), do: unquote(description)
  end)
end
