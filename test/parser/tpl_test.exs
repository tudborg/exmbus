defmodule Parser.TplTest do
  use ExUnit.Case, async: true
  doctest Exmbus.Parser.Tpl, import: true
  doctest Exmbus.Parser.Tpl.Device, import: true
  doctest Exmbus.Parser.Tpl.ConfigurationField, import: true

  alias Exmbus.Parser.Tpl.ConfigurationField

  test "truncated configuration field returns error" do
    assert {:error, {:invalid_configuration_field, :truncated}} = ConfigurationField.parse(<<0>>)
  end

  test "truncated mode 7 configuration field extension returns error" do
    bin = <<0::4, 0::1, 0::3, 0::2, 1::1, 7::5, 0::1, 0::1, 0::2, 0::4>>

    assert {:error, {:invalid_configuration_field, :truncated}} = ConfigurationField.parse(bin)
  end

  test "unsupported short tpl configuration mode returns parse error" do
    handler = &Exmbus.Parser.Tpl.parse/1
    ctx = Exmbus.Parser.Context.new(handlers: [handler])

    assert {:error, %{errors: [{^handler, {:not_implemented, {:encryption_mode, 1}}}]}} =
             Exmbus.parse(<<0x7A, 0, 0, 0, 0::3, 1::5>>, ctx)
  end
end
