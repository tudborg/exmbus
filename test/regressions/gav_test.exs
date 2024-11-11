defmodule Regressions.GAVTest do
  use ExUnit.Case, async: true

  alias Exmbus.Parser.Apl.FullFrame
  alias Exmbus.Parser.Apl.DataRecord
  alias Exmbus.Parser.Tpl
  alias Exmbus.Parser.Dll.Mbus

  describe "GAV" do
    test "Record not parsing correctly, missing VIF implementation" do
      bytes =
        "6869696808017222070000361CDE02A12000000703AD3D00000000000004FB827501000000042A59F5FFFF04FB977224E4FFFF04FBB772C22C000002FDBA7313FF84808040FD48BD0F000004FD48160900008440FD59C6050000848040FD59E206000084C040FD59950600001F9616"
        |> Base.decode16!()

      assert {:ok, ctx} = Exmbus.parse(bytes, length: false)

      assert %{
               apl: %FullFrame{
                 manufacturer_bytes: "",
                 records:
                   [
                     %DataRecord{},
                     %DataRecord{},
                     %DataRecord{},
                     %DataRecord{},
                     %DataRecord{},
                     %DataRecord{},
                     %DataRecord{},
                     %DataRecord{},
                     %DataRecord{},
                     %DataRecord{},
                     %DataRecord{}
                   ] = records
               },
               tpl: %Tpl{
                 frame_type: :full_frame,
                 header: %Tpl.Header.Long{
                   access_no: 161,
                   configuration_field: %Tpl.ConfigurationField{
                     accessibility: false,
                     bidirectional: false,
                     blocks: nil,
                     content_of_message: 0,
                     hop_count: 0,
                     mode: 0,
                     repeater_access: 0,
                     syncrony: false
                   },
                   status: %Tpl.Status{
                     application_status: :no_error,
                     low_power: false,
                     manufacturer_status: 1,
                     permanent_error: false,
                     temporary_error: false
                   },
                   device: :electricity,
                   identification_no: 722,
                   manufacturer: "GAV",
                   version: 222
                 }
               },
               dll: %Mbus{
                 control: :rsp_ud,
                 address: 1
               }
             } = ctx

      # check that all records can be parsed
      assert [
               %DataRecord{header: %{vib: %{extensions: ex1}}},
               %DataRecord{header: %{vib: %{extensions: ex2}}},
               %DataRecord{header: %{vib: %{extensions: ex3}}},
               %DataRecord{header: %{vib: %{extensions: ex4}}},
               %DataRecord{header: %{vib: %{extensions: ex5}}},
               %DataRecord{header: %{vib: %{extensions: ex6}}},
               %DataRecord{header: %{vib: %{extensions: ex7}}},
               %DataRecord{header: %{vib: %{extensions: ex8}}},
               %DataRecord{header: %{vib: %{extensions: ex9}}},
               %DataRecord{header: %{vib: %{extensions: ex10}}},
               %DataRecord{header: %{vib: %{extensions: ex11}}}
             ] = records

      assert [] = ex1
      assert [{:multiplicative_correction_factor, 0.1}] = ex2
      assert [] = ex3
      assert [{:multiplicative_correction_factor, 0.0001}] = ex4
      assert [{:multiplicative_correction_factor, 0.0001}] = ex5
      assert [{:multiplicative_correction_factor, 0.001}] = ex6
      assert [] = ex7
      assert [] = ex8
      assert [] = ex9
      assert [] = ex10
      assert [] = ex11
    end
  end
end
