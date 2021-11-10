
defmodule Exmbus.Apl.DataRecord.Header do
  alias Exmbus.Apl.DataRecord.DataInformationBlock, as: DIB
  alias Exmbus.Apl.DataRecord.ValueInformationBlock, as: VIB

  use Bitwise

  # The header struct
  defstruct [
    # DIB fields:
    device: nil,
    tariff: nil,
    storage: nil,
    function_field: nil,
    # the coding and size comes from decoding the Data Field in the DIB
    # they are split for easier access
    coding: nil,
    size: nil,
    # VIB fields:
    description: nil, # An atom describing the value. This is an atomized version of the "Description" from the documentation.
    multiplier: nil,  # A multiplier to apply to the data. It's part of the VIF(E) information.
    unit: nil,        # A string giving the unit of the value (e.g. kJ/h or °C)
    extensions: [],   # A list of extensions that might modify the meaning of the data.
    # Implied by a combination of the above
    data_type: nil,  # If set, decode according to this datatype instead of what is found in the DIF
                     # Options are: type_a, type_b, type_c, type_d, type_f, type_g,
                     #              type_h, type_i, type_j, type_k, type_l, type_m
  ]

  @doc """
  Parses the next DataRecord Header from a binary.
  """
  @spec parse(binary())
    :: {:ok, (header :: %__MODULE__{}) | {:special_function, type :: term()}, rest :: binary()}
  def parse(bin, opts \\ []) do
    case parse_dib(%__MODULE__{}, bin, opts) do
      {:special_function, type, rest}=special_function ->
        # we just return the special function. The parser upstream will have to decide what to do,
        # but there isn't a real header here. The APL layer knows what to do.
        special_function
      {:ok, %__MODULE__{}=header, rest} ->
        # We found a DataInformationBlock and have filled in the header so far.
        # We now expect a VIB to follow, which needs the context from the DIB to be able to parse
        # correctly.
        parse_vib(header, rest, opts)
    end
  end

  def parse_dib(header, <<special::4, 0b1111::4, rest::binary>>, _opts) do
    # note that we are effectively stripping the least-significant bits of the dif which is
    # always 0b1111 (i.e. 0xF) for special functions, so the following case only checks for the top
    # 4 bits. In the manual these are written together (i.e. 0x0F), here we only write the MSB (0x0 instead of 0x0F)
    case special do
      # Start of manufacturer specific data structures to end of user data(see 6.5)
      0x0 -> {:special_function, {:manufacturer_specific, :to_end}, rest}
      # Same meaning as DIF = 0Fh + more records follow in next datagram (see 6.5)
      0x1 -> {:special_function, {:manufacturer_specific, :more_records_follow}, rest}
      # Idle filler, following byte is DIF, we could just recurse directly but let's keep the structure and return a special
      0x2 -> {:special_function, :idle_filler, rest}
      # special function range reserved for future use
      r when r >= 0x3 and r <= 0x6 -> raise "special function DIF 0x#{Integer.to_string((r <<< 4) ||| 0xF, 16)} reserved for future use"
      # Global readout request (all storage numbers, units, tariffs, function fields)
      # TODO what does this mean exactly?
      0x7 -> {:special_function, :global_readout_request, rest}
    end
  end
  # regular DIF parsing:
  def parse_dib(header, <<e::1, lsb_storage::1, ff::2, df::4, rest::binary>>, _opts) do
    {:ok, device, tariff, msb_storage, rest} =
      case e do
        # if extensions, decode dife:
        1 -> parse_header_dife(rest)
        # else return defaults:
        0 -> {:ok, 0, 0, 0, rest}
      end
    #
    storage = (msb_storage <<< 1) ||| lsb_storage
    {default_data_type, coding, size} = DIB.decode_data_field(df)
    {:ok, %{header |
      device: device,
      tariff: tariff,
      storage: storage,
      function_field: DIB.decode_function_field(ff),
      coding: coding,
      size: size,
      data_type: default_data_type,
    }, rest}
  end

  # decodes series of DIFE bytes.
  # Note that this function should only be called if the DIF had the extension bit set.
  defp parse_header_dife(<<0::1, device::1, tariff::2, storage::4, rest::binary>>) do
    {:ok, device, tariff, storage, rest}
  end
  defp parse_header_dife(<<1::1, l_device::1, l_tariff::2, l_storage::4, rest::binary>>) do
    {:ok, m_device, m_tariff, m_storage, rest} = parse_header_dife(rest)
    {:ok,
      (m_device <<< 1) ||| l_device,
      (m_tariff <<< 2) ||| l_tariff,
      (m_storage <<< 4) ||| l_storage,
      rest
    }
  end

  #
  #
  #

  def parse_vib(header, bin, opts \\ []) do
    # the :main is the default decode table name
    parse_vib(header, :main, bin, opts)
  end

  # linear VIF-extension: EF, reserved for future use
  defp parse_vib(_header, _table, <<0xEF, _rest::binary>>, _opts) do
    raise "VIF 0xEF reserved for future use."
  end
  # plain-text VIF:
  defp parse_vib(header, _table, <<_::1, 0b111_1100::7, rest::binary>>, opts) do
    case parse_vifes(header, rest, opts) do
      {:ok, %__MODULE__{}=header, <<len, rest::binary>>} ->
        # the unit is found after the VIB, so we now need to read the unit out from the rest of the data
        <<ascii_vif::binary-size(len), rest::binary>> = rest
        {:ok, %__MODULE__{header | description: {:user_defined, ascii_vif}}, rest}
    end
  end
  # Any VIF: 7E / FE
  # This VIF-Code can be used in direction master to slave for readout selection of all VIFs.
  # See special function in 6.3.3
  defp parse_vib(_header, _table, <<_::1, 0b1111110::7, _rest::binary>>, _opts) do
    raise "Any VIF 0x7E / 0xFE not implemented. See 6.4.1 list item d."
  end
  # Manufacturer specific encoding, 7F / FF.
  # Rest of data-record (including VIFEs) are manufacturer specific.
  defp parse_vib(%__MODULE__{description: nil, extensions: exts}=header, _table, <<_::1, 0b1111111::7, rest::binary>>, _opts) do
    {vifes, rest} = split_by_extension_bit(rest)

    manufacturer_specific_vifes =
      vifes
      |> :binary.bin_to_list()
      |> Enum.map(&({:manufacturer_specific_vife, &1}))

    {:ok, %__MODULE__{header | description: :manufacturer_specific_encoding, extensions: manufacturer_specific_vifes ++ exts}, rest}
    #raise "Manufacturer-specific VIF encoding not implemented. See 6.4.1 list item e."
  end
  # linear VIF-extension: 0xFD, decode vif from table 14.
  defp parse_vib(header, _table, <<0xFD, rest::binary>>, opts) do
    parse_vib(header, 0xFD, rest, opts)
  end
  # linear VIF-extension: FB, decode vif from table 12.
  defp parse_vib(header, _table, <<0xFB, rest::binary>>, opts) do
    parse_vib(header, 0xFB, rest, opts)
  end
  defp parse_vib(header, table, <<vif::binary-size(1), rest::binary>>, opts) do
    case VIB.decode_vif_table(header, table, vif) do
      {:ok, %__MODULE__{}=header} ->
        case vif do
          # Do we have VIF extensions?
          # yes:
          <<1::1, _::7>> -> parse_vifes(header, rest, opts)
          # no:
          <<0::1, _::7>> -> {:ok, header, rest}
        end
    end
  end

  defp parse_vifes(_header, <<_::1, 0b000::3, _::4, _rest::binary>>, _opts) do
    raise "VIFE 0bE000XXXX reserved for object actions (master to slave) (6.4.7) or for error codes (slave to master) (6.4.8)"
  end
  defp parse_vifes(_header, <<_::1, 0b0010000::7, _rest::binary>>, _opts) do
    raise "VIFE E0010000 reserved"
  end
  defp parse_vifes(_header, <<_::1, 0b0010001::7, _rest::binary>>, _opts) do
    raise "VIFE E0010001 reserved"
  end
  # Unknown VIFE (We have not implemented a specific atom for it, and don't know how it affects the value)
  defp parse_vifes(%__MODULE__{extensions: exts}=header ,<<ext::1, vife::7, rest::binary>>, opts) do
    # the vife is unknown. We add it as unknown to the extensions list.
    header = %__MODULE__{header | extensions: [{{:unknown_vife, vife}} | exts]}
    case ext do
      0 -> {:ok, header, rest}
      1 -> parse_vifes(header, rest, opts)
    end
  end



  @doc """
  Splits a binary into two, so that the left side contains a binary of all bytes
  up to and including a byte without it's extension bit (MSB) set.

  This is the way DRH blocks are seperated.

    iex> split_by_extension_bit(<<0b0000_0000, 0xFF>>)
    {<<0x00>>, <<0xFF>>}

    iex> split_by_extension_bit(<<0b0000_0000, 0b0000_0000, 0xFF>>)
    {<<0x00>>, <<0x00, 0xFF>>}

    iex> split_by_extension_bit(<<0b1000_0000, 0b0000_0000, 0xFF>>)
    {<<0b10000000, 0b00000000>>, <<0xFF>>}
  """
  @spec split_by_extension_bit(binary()) :: {binary(), binary()}
  def split_by_extension_bit(<<byte::binary-size(1), rest::binary>>) do
    case byte do
      <<0::1, _::7>> ->
        {byte, rest}
      <<1::1, _::7>> ->
        {tail, rest} = split_by_extension_bit(rest)
        {<<byte::binary, tail::binary>>, rest}
    end
  end





end
