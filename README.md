# Exmbus

You can run integration tests with `mix test --include integration:true`


## TODO

- Implement examples from documentation as tests.
- Implement Authentication and fragmentation layer CI=90
  Example:
  `4474260730381029078C20EF900F002C2503A2F08F49703C7E1904BAF77ACF00300710E1AC2507238AF96DE27F1F5B28D2437F5D8A05E7ACE10AA95F84000F6E63856AD8870BE28AEED46ED706E81C3472FCBB`
- DLL CRC support. Currently CRC is hand-stripped from the specification examples.


## Elixir

Unpack Qundis Walk-by data:

```elixir
defmodule Qundis do

  @spec decode_walk_by_data(parsed_frame :: map(), keys :: list())
  :: {:ok, parsed :: map()} | {:error, any()}
  def decode_walk_by_data(parsed, keys \\ []) do
    case Enum.find(parsed.fields, &find_walk_by/1) do
      nil -> {:ok, parsed}
      %{value: walk_by} ->
        with {:ok, parsed} <- update_meta(parsed, walk_by),
             {:ok, decrypted} <- decrypt_and_parse(parsed, walk_by, keys) do
          update_fields(parsed, decrypted)
        end
    end
  end

  @spec find_walk_by(parsed_frame :: %{ any() => any() }) :: boolean()
  defp find_walk_by(%{vif: "Qundis walk by data", value: v}) when is_binary(v), do: true
  defp find_walk_by(_), do: false

  @spec update_meta(parsed_frame :: %{ any() => any() }, binary())
  :: {:ok, map()}
  defp update_meta(parsed,   <<0, 0x82, acc, status, _::binary>>) do
    {:ok, Map.merge(parsed, %{acc: acc, status: status})}
  end
  defp update_meta(parsed, _), do: {:ok, parsed}

  @spec decrypt_and_parse(%{
        :device => integer(),
        :fields => any(),
        :manufacturer_code => integer(),
        :serial => integer(),
        :version => integer(),
        any() => any() }, walk_by :: <<_::40>>, any())
  :: {:error, :unable_to_decrypt} | {:ok, [any(), ...]}
  defp decrypt_and_parse(parsed, walk_by= <<0, 0x82, _, _, 0, _::binary>>, _) do
    parse(parsed, walk_by)
  end
  defp decrypt_and_parse(parsed, walk_by, [key|rest]) do
    with {:ok, decrypted} <- decrypt(parsed, walk_by, key),
         {:ok, parsed} <- parse(parsed, decrypted) do
      {:ok, parsed}
    else
      {:error, {:invalid_vif, _}} -> decrypt_and_parse(parsed, walk_by, rest)
      {:error, :invalid_key} -> decrypt_and_parse(parsed, walk_by, rest)
      {:error, message} -> {:error, message}
    end
  end
  defp decrypt_and_parse(_parsed, _walk_by, []) do
    {:error, :unable_to_decrypt}
  end

  @spec decrypt(
    %{
      :device => integer(),
      :fields => any(),
      :manufacturer_code => integer(),
      :serial => integer(),
      :version => integer(),
      any() => any()
    }, <<_::40>>, binary())
  :: {:error, :invalid_key} | {:ok, <<_::64>>}

  defp decrypt(parsed, <<0, 0x82, acc, status, 0x35, encrypted::binary>>, key) when is_binary(key) and bit_size(key) == 128 do
    bcd_serial = MeterBus.Helpers.int_to_bcd(parsed.serial)
    iv = <<
    parsed.manufacturer_code::little-size(16),
    bcd_serial::little-size(32),
    parsed.version, parsed.device,
    acc, acc, acc, acc, acc, acc, acc, acc
    >>
    case :crypto.block_decrypt(:aes_cbc, key, iv, encrypted) do
      decrypted = <<_::binary-size(47), 0x2f>> ->
        {:ok, <<0, 0x82, acc, status, 0, decrypted::binary>>}
      _ ->
        {:error, :invalid_key}
    end
  end

  @spec parse(%{:fields => any(), any() => any()}, <<_::64>>) ::
  {:error, {:invalid_vif, <<_::8>>}} | {:ok, [any(), ...]}

  defp parse(parsed = %{}, walk_by) do
    <<0, 0x82, _, _, 0, _::size(16), _, _dif::size(4), _::size(1), _exp::size(3), vif,
    err::binary-size(2),
    current_value::size(32),
    cutoff_date::size(16),
    cutoff_value::size(32),
    last_month_end::size(16),
    last_month_value::size(32),
    _::binary
    >> = walk_by
    error_date = case err do
       <<0xff, 0xff>> ->
        "No error"
      date ->
        MeterBus.Parser.DataTypes.parse_type_g(date)
    end

    # TODO: Qundis said the dif should be the upper bytes of the DRB,
    #       however that would fail since 0x0b is three bytes long, and
    #       all the values in the telegram are 4 bytes. Thus the value
    #       is forced here
    dif = 0xc

    fieldsstring = <<
    0x0::size(4), dif::size(4), vif, current_value::size(32),
    0x42, 0x6c, cutoff_date::size(16),
    0x4::size(4), dif::size(4), vif, cutoff_value::size(32),
    0x82, 0x01, 0x6c, last_month_end::size(16),
    0x8::size(4), dif::size(4), 0x01, vif, last_month_value::size(32),
    >>

    case MeterBus.Parser.Fields.parse(fieldsstring, parsed) do
      {:error, message} ->
         {:error, message}
      fields when is_list(fields)->
        {:ok, [%{vif: "Error date", value: error_date} | fields]}
    end
  end

  @spec update_fields(%{ :device => integer(),
                         :fields => [any()],
                         :manufacturer_code => integer(),
                         :serial => integer(),
                         :version => integer()}, [any(), ...])
  :: {:ok, %{ :device => integer(),
              :fields => [any()],
              :manufacturer_code => integer(),
              :serial => integer(),
              :version => integer() }}
  defp update_fields(parsed = %{}, new_fields) do
    i = Enum.find_index(parsed.fields, &find_walk_by/1)
    fields = parsed.fields
              |> List.replace_at(i, new_fields)
              |> List.flatten
    {:ok, Map.put(parsed, :fields, fields)}
  end
end

```
