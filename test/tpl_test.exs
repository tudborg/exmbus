defmodule TplTest do
  use ExUnit.Case

  alias Exmbus.Tpl
  alias Exmbus.Apl

  doctest Exmbus.Tpl, import: true

  test "MBus full frame, long header" do
    # tpl_layer = Base.decode16!("7278563412931533032A0000000C1427048502046D32371F1502FD170000")
    # assert {:ok, %Tpl{
    #   header: %Tpl.Long{
    #     manufacturer: "ELS",
    #     identification_no: 12345678,
    #     device: :gas,
    #     version: 51,
    #     access_no: 42,
    #     status: %Tpl.Status{
    #       application_status: :no_error,
    #       low_power: false,
    #       manufacturer_status: 0,
    #       permanent_error: false,
    #       temporary_error: false,
    #     },
    #     configuration_field: %Tpl.ConfigurationField{
    #       accessibility: false,
    #       bidirectional: false,
    #       blocks: nil,
    #       content_of_message: 0,
    #       hop_count: 0,
    #       mode: 0,
    #       repeater_access: 0,
    #       syncrony: false,
    #     }
    #   },
    #   apl: %Apl{
    #     manufacturer_data: nil,
    #     records: [%Apl.DataRecord{}, %Apl.DataRecord{}, %Apl.DataRecord{}]
    #   },
    # }, _} = Tpl.decode(tpl_layer)
  end

end
