defmodule Exmbus.Message do
  @moduledoc """
  This is a structure for a simplified internal representation of a parsed datagram(s).
  It collapes some fields into one.
  """

  alias Exmbus.Tpl
  alias Exmbus.Apl
  alias Exmbus.Dll.Wmbus

  defstruct [
    parsed: nil,

    manufacturer: nil,
    identification_no: nil,
    device: nil,
    version: nil,
  ]

  @doc """
  Create a Message struct from parsed list
  """
  def from_parsed(parsed, opts \\ []) do
    # Gather manufacturer, identification number, device, version
    {:ok, {m, i, d, v}} = gather_m_i_d_v(parsed, nil, nil, nil, nil, opts)

    {:ok, %__MODULE__{
      parsed: parsed,
      manufacturer: m,
      identification_no: i,
      device: d,
      version: v,
    }}
  end

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



end
