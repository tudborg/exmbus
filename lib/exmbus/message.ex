defmodule Exmbus.Message do
  @moduledoc """
  This is a structure for a simplified internal representation of a parsed datagram(s).
  It collapes some fields into one.
  """

  alias Exmbus.Tpl
  alias Exmbus.Apl
  alias Exmbus.Apl.DataRecord
  alias Exmbus.Dll.Wmbus

  defstruct [
    raw: nil, # raw internal parsed layers.
    records: nil, # [%DataRecord{}]
    manufacturer: nil,
    identification_no: nil,
    device: nil,
    version: nil,
  ]

  @doc """
  Create a Message struct from parsed list
  """
  def from_parsed(parsed, opts  \\ %{})
  def from_parsed(parsed, opts) when is_list(opts), do: from_parsed(parsed, opts |> Enum.into(%{}))
  def from_parsed(parsed, opts) when is_map(opts) do
    # Gather manufacturer, identification number, device, version
    {:ok, {m, i, d, v}} = gather_m_i_d_v(parsed, nil, nil, nil, nil, opts)
    {:ok, records} = gather_records(parsed, opts)

    parsed = case Map.get(opts, :keep_raw, false) do
      true -> parsed
      false -> nil
    end

    {:ok, %__MODULE__{
      raw: parsed,
      records: records,
      manufacturer: m,
      identification_no: i,
      device: d,
      version: v,
    }}
  end

  ##
  ## Getters:
  ##

  def to_map!(%__MODULE__{manufacturer: manufacturer, identification_no: identification_no, device: device, version: version, records: records}) do
    %{
      manufacturer: manufacturer,
      identification_no: identification_no,
      device: device,
      version: version,
      records: Enum.map(records, &DataRecord.to_map!/1),
    }
  end


  @doc """
  Returns a tuple {value, unit} of the first record that matches the given requirements.

  You can pass a function that takes a %DataRecord{} and returns true | false,
  or you can pass a Keyword list specifying what requirements you are looking for.
  The available requirements are:

  - :storage
  - :device
  - :tariff
  - :function_field
  - :description
  - :unit
  """
  def filter_records(%__MODULE__{records: records}, requirements) do
    find_fn =
      case requirements do
        l when is_list(l) -> fn record -> record_matches?(record, requirements) end
        f when is_function(f, 1) -> f
      end
    Enum.filter(records, find_fn)
  end

  # helper for checking if a record matches a set of requirements
  defp record_matches?(record, []), do: true
  defp record_matches?(%DataRecord{header: %{storage: v}}=r, [{:storage, v} | rest]), do: record_matches?(r, rest)
  defp record_matches?(%DataRecord{header: %{device: v}}=r, [{:device, v} | rest]), do: record_matches?(r, rest)
  defp record_matches?(%DataRecord{header: %{tariff: v}}=r, [{:tariff, v} | rest]), do: record_matches?(r, rest)
  defp record_matches?(%DataRecord{header: %{function_field: v}}=r, [{:function_field, v} | rest]), do: record_matches?(r, rest)
  defp record_matches?(%DataRecord{header: %{description: v}}=r, [{:description, v} | rest]), do: record_matches?(r, rest)
  defp record_matches?(%DataRecord{}=r, [{:unit, u} | rest]), do: DataRecord.unit!(r) == u and record_matches?(r, rest)
  defp record_matches?(_, _), do: false

  ##
  ## Construction helpers:
  ##

  # Gather manufacturer, identification number, device, version from parsed layers,
  # returning as soon as we have found it.
  defp gather_m_i_d_v(_, m, i, d, v, _opts) when not (is_nil(m) or is_nil(i) or is_nil(d) or is_nil(v)) do
    {:ok, {m, i, d, v}}
  end
  # error if we fail. Shouldn't happen for valid parse results
  defp gather_m_i_d_v([], m, i, d, v, _opts) do
    {:error, {:could_not_gather_m_i_d_v, {m, i, d, v}}}
  end
  # Gather from APL
  defp gather_m_i_d_v([%Apl{} | rest], m, i, d, v, opts) do
    gather_m_i_d_v(rest, m, i, d, v, opts)
  end
  # Gather from TPL
  defp gather_m_i_d_v([%Tpl{header: %Tpl.Long{}=long} | rest], m, i, d, v, opts) do
    # gather the ones not already set from Long header
    gather_m_i_d_v(rest,
      m || long.manufacturer,
      i || long.identification_no,
      d || long.device,
      v || long.version,
      opts)
  end
  # any other TPL doesn't have midv
  defp gather_m_i_d_v([%Tpl{header: _} | rest], m, i, d, v, opts) do
    gather_m_i_d_v(rest, m, i, d, v, opts)
  end
  # DLL Wmbus
  defp gather_m_i_d_v([%Wmbus{}=dll | rest], m, i, d, v, opts) do
    gather_m_i_d_v(rest,
      m || dll.manufacturer,
      i || dll.identification_no,
      d || dll.device,
      v || dll.version,
      opts)
  end
  # gather (normalized) record values into a map
  defp gather_records([%Apl{records: records} | _], _opts) do
    {:ok, records}
  end

end



