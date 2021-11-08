defmodule LiveGatewayExportTest do
  NimbleCSV.define(CSV, separator: ",", escape: "\"")

  use ExUnit.Case
  require Logger

  alias Exmbus.Message
  alias Exmbus.Apl.DataRecord
  alias Exmbus.Apl
  alias Exmbus.Apl.EncryptedApl
  alias Exmbus.Tpl
  alias Exmbus.Dll.Wmbus

  defp parse_export(filename) do
    Path.join(__DIR__, filename)
    |> File.stream!()
    |> CSV.parse_stream()
  end

  defp handle_csv_line([expected_manufacturer, expected_serial, hexdata]) do
    assert %{} =
             hexdata
             |> Base.decode16!()
             |> Exmbus.simplified!(length: false)
  end

  test "ABB" do
    "live_gateway_export_abb.csv"
    |> parse_export()
    |> Enum.map(&handle_csv_line/1)
  end

  test "BMT" do
    "live_gateway_export_bmt.csv"
    |> parse_export()
    |> Enum.map(&handle_csv_line/1)
  end

  test "DME" do
    "live_gateway_export_dme.csv"
    |> parse_export()
    |> Enum.map(&handle_csv_line/1)
  end

  test "HYD" do
    "live_gateway_export_hyd.csv"
    |> parse_export()
    |> Enum.map(&handle_csv_line/1)
  end

  test "KAM" do
    "live_gateway_export_kam.csv"
    |> parse_export()
    |> Enum.map(&handle_csv_line/1)
  end

  test "QDS" do
    "live_gateway_export_qds.csv"
    |> parse_export()
    |> Enum.map(&handle_csv_line/1)
  end

  test "TCH" do
    "live_gateway_export_tch.csv"
    |> parse_export()
    |> Enum.map(&handle_csv_line/1)
  end

  test "WEH" do
    "live_gateway_export_weh.csv"
    |> parse_export()
    |> Enum.map(&handle_csv_line/1)
  end
end
