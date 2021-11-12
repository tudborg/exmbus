defmodule Exmbus.Message do
  @moduledoc """
  This is a structure for a simplified internal representation of a parsed datagram(s).
  The raw layers can optionally be kept as well with the `:keep_layers` option.
  """

  alias Exmbus.Tpl
  alias Exmbus.Apl
  alias Exmbus.Ell
  alias Exmbus.Dll.Wmbus

  defstruct [
    layers: nil, # internal parsed layer list

    records: nil, # [%DataRecord{}]
    manufacturer: nil,
    identification_no: nil,
    device: nil,
    version: nil,
  ]

  @doc """
  Parses a binary into a Message structure.
  This is the raising version of parse/2
  """
  def parse!(bin, opts \\ %{}) do
    case parse(bin, opts) do
      {:ok, message} -> message
      {:error, reason, partial_ctx} -> raise "parse!/2 failed with reason=#{inspect reason} ctx=#{inspect partial_ctx}"
      {:error, reason} -> raise "parse!/2 failed with reason=#{inspect reason}"
    end
  end

  @doc """
  Parses a binary into a Message structure.
  This function will guess what DLL is being used and parse accordingly.
  You can parse using a specific DLL using one of the parse_* functions.
  """
  def parse(bin, opts \\ %{})

  def parse(bin, opts) when is_list(opts), do: parse(bin, opts |> Enum.into(%{}))
  # Try to auto-guess what type of DLL is used
  # If the signature is start,length,length,start it's probably MBus DLL
  def parse(<<s, l, l, s, _::binary>>=bin, opts) when is_binary(bin), do: parse_mbus(bin ,opts)
  # otherwise probably WMBus
  def parse(bin, opts) when is_binary(bin), do: parse_wmbus(bin, opts)

  @doc """
  Parses a binary into a Message struct.
  The binary must be a WMBus DLL binary
  """
  def parse_wmbus(bin, opts) do
    with {:ok, layers} <- Wmbus.parse(bin, opts, []) do
      from_layers(layers, opts)
    end
  end
  @doc """
  Parses a binary into a Message struct.
  The binary must be an MBus DLL binary
  """
  def parse_mbus(_bin, _opts) do
    raise "TODO"
    # case Mbus.parse(bin, opts, []) do
    #   {:ok, layers} -> from_layers(layers, opts)
    # end
  end

  @doc """
  Create a Message struct from a layer list.
  The layer list is returned from some of the initial layer parsers like DLL.Wmbus.

  If the APL layer is encrypted this function will return a Message struct where
  the records field is set to `:encrypted`.

  You can decrypt the APL by supplying a `:key` option to this function as an option.
  `:key` must be a `Exmbus.Key` struct.
  """
  def from_layers(layers, opts  \\ %{})
  def from_layers(layers, opts) when is_list(opts), do: from_layers(layers, opts |> Enum.into(%{}))
  def from_layers(layers, opts) when is_map(opts) do
    # Gather manufacturer, identification number, device, version
    {:ok, {m, i, d, v}} = gather_m_i_d_v(layers, nil, nil, nil, nil, opts)
    {:ok, records} = gather_records(layers, opts)
    # If we successfully gathered records, we only keep the original layers list
    # if :keep_layers is set true in the options.
    layers = case Map.get(opts, :keep_layers, false) do
      true -> layers
      false -> nil
    end
    {:ok, %__MODULE__{
      layers: layers,
      records: records,
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
  defp gather_m_i_d_v([%Apl.FullFrame{} | rest], m, i, d, v, opts) do
    gather_m_i_d_v(rest, m, i, d, v, opts)
  end
  defp gather_m_i_d_v([%Apl.FormatFrame{} | rest], m, i, d, v, opts) do
    gather_m_i_d_v(rest, m, i, d, v, opts)
  end
  defp gather_m_i_d_v([%Apl.CompactFrame{} | rest], m, i, d, v, opts) do
    gather_m_i_d_v(rest, m, i, d, v, opts)
  end
  defp gather_m_i_d_v([%Apl.Raw{} | rest], m, i, d, v, opts) do
    gather_m_i_d_v(rest, m, i, d, v, opts)
  end
  defp gather_m_i_d_v([%Ell{} | rest], m, i, d, v, opts) do
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
  # gather records
  defp gather_records([%Apl.FullFrame{records: records} | _], _opts) do
    {:ok, records}
  end
  defp gather_records([%Apl.CompactFrame{} | _], _opts) do
    {:ok, :compact_frame}
  end
  defp gather_records([%Apl.FormatFrame{} | _], _opts) do
    {:ok, :format_frame}
  end
  defp gather_records([%Apl.Raw{mode: n} | _], _opts) when n > 0 do
    {:ok, :encrypted}
  end

end



