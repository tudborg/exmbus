defmodule Exmbus.Apl.DataRecord.ValueInformationBlock do
  @moduledoc """
  The Value Information Block.
  Contains the DIF+DIFE
  """

  use Bitwise

  defstruct [
    description: nil, # An atom describing the value. This is an atomized version of the "Description" from the documentation.
    multiplier: nil,  # A multiplier to apply to the data. It's part of the VIF(E) information.
    unit: nil,        # A string giving the unit of the value (e.g. kJ/h or °C)
    extensions: [],   # A list of extensions that might modify the meaning of the data.
  ]

  @doc """
  Decode VIB (Value Information Block) and return a %ValueInformationBlock{} struct and rest of data.

  There are 5 types of coding depending on the VIF:
  - primary VIF: 0bE000_0000 to 0bE111_1010
  - plain-text VIF: 0bE111_1100
  - linear VIF-extension FD and FB
  - Any VIF: 7E / FE
  - Manufacturer-specific: 7F / FF


    iex> decode(<<0b00000011, 0xFF>>)
    {:ok, %ValueInformationBlock{
      description: :energy,
      multiplier: 1,
      unit: "Wh",
      extensions: [],
    }, <<0xFF>>}

    iex> decode(<<0b0111_1100, 5, 104, 101, 108, 108, 111, 0xFF>>)
    {:ok, %ValueInformationBlock{
      description: :plain_text,
      multiplier: nil, # no multiplier for text
      unit: "hello",
      extensions: [],
    }, <<0xFF>>}

  """
  @spec decode(binary(), [opt :: any()]) :: {:ok, %__MODULE__{}, rest :: binary()}
  def decode(bin, opts \\ []) do
    # collect all the relevant bytes up front for easier parsing.
    # I don't think this is ideal for performance but it's probably Good Enough.
    {vifs, rest} = collect_vifs(bin)
    decode_vifs(vifs, rest, opts)
  end

  # linear VIF-extension: EF, reserved for future use
  defp decode_vifs([<<0xFB>> | _tail], _rest, _opts), do: raise "VIF 0xEF reserved for future use."
  # plain-text VIF:
  defp decode_vifs([<<_::1, 0b111_1100::7>> | tail], <<len, rest::binary>>, opts) do
    # the VIF is len from rest decoded as ASCII (which is "just is" so easy)
    <<plaintext::binary-size(len), rest::binary>> = rest
    decode_vifes(tail, rest, %__MODULE__{description: :plain_text, unit: plaintext}, opts)
  end
  # Any VIF: 7E / FE
  # This VIF-Code can be used in direction master to slave for readout selection of all VIFs.
  # See special function in 6.3.3
  defp decode_vifs([<<_::1, 0b1111110::7>> | _tail], _rest, _opts) do
    raise "Any VIF 0x7E / 0xFE not implemented. See 6.4.1 list item d."
  end
  # manufacturer specific encoding. All bets are off.
  defp decode_vifs([<<_::1, 0b1111111::7>> | _tail], _rest, _opts) do
    raise "Manufacturer-specific VIF encoding not implemented. See 6.4.1 list item e."
  end
  # linear VIF-extension: 0xFD, decode vif from table 14.
  defp decode_vifs([<<0xFD>>, vif | tail], rest, opts) do
    case decode_vif_fd(vif) do
      {:ok, {description, multiplier, unit}} ->
        decode_vifes(tail, rest, %__MODULE__{description: description, multiplier: multiplier, unit: unit}, opts)
    end
  end
  # linear VIF-extension: FB, decode vif from table 12.
  defp decode_vifs([<<0xFB>>, vif | tail], rest, opts) do
    case decode_vif_fb(vif) do
      {:ok, {description, multiplier, unit}} ->
        decode_vifes(tail, rest, %__MODULE__{description: description, multiplier: multiplier, unit: unit}, opts)
    end
  end
  # primary VIF (main table) decode.
  defp decode_vifs([vif | tail], rest, opts) do
    case decode_vif_primary(vif) do
      {:ok, {description, multiplier, unit}} ->
        decode_vifes(tail, rest, %__MODULE__{description: description, multiplier: multiplier, unit: unit}, opts)
    end
  end

  # vifes is a list of vife bytes
  # rest is the rest of the telegram binary
  # struct is an initialized ValueInformationBlock from previous VIF
  # opts is options from the outside.
  defp decode_vifes([], rest, struct, _opts) do
    # no more VIFE bytes to decode, return struct and rest
    {:ok, struct, rest}
  end
  defp decode_vifes([<<_::1, 0b000::3, _::4>>=vife | _tail], _rest, _struct, _opts) do
    raise "VIFE #{u8_to_hex(vife)} reserved for object actions (master to slave) (6.4.7) or for error codes (slave to master) (6.4.8)"
  end
  defp decode_vifes([<<_::1, 0b0010000::7>> = vife | _tail], _rest, _struct, _opts) do
    raise "VIFE E0010000 (#{u8_to_hex(vife)}) reserved"
  end
  defp decode_vifes([<<_::1, 0b0010001::7>> = vife | _tail], _rest, _struct, _opts) do
    raise "VIFE E0010001 (#{u8_to_hex(vife)}) reserved"
  end
  defp decode_vifes([vife | _tail], _rest, _struct, _opts) do
    raise "VIFE #{u8_to_hex(vife)} not implemented"
  end


  # returns 10^power but makes sure it is only a float if it has to be.
  # since we know it's 10^pow we can round to integers when the result is >= 1.0
  # we do this because that way we can maintain the appearance (and infinite precision) of BEAM integers
  # where possible, however this also means that the datatype of the final multiplication differs
  # depending on the datatype, allowing the same kind of value to be both float and integer.
  # If this is relevant, the user can coerce from int to float where needed. The other way is harder.
  defp pow10to(power) do
    case :math.pow(10, power) do
      f when f < 1.0 -> f
      i when i >= 1.0 -> round(i)
    end
  end

  ###
  # primary VIF table decoding
  ###
  defp decode_vif_primary(<<_::1, 0b0000::4,  n::3>>), do: {:ok, {:energy, pow10to(n-3), "Wh"}}
  defp decode_vif_primary(<<_::1, 0b0001::4,  n::3>>), do: {:ok, {:energy, pow10to(n), "kJ"}}
  defp decode_vif_primary(<<_::1, 0b0010::4,  n::3>>), do: {:ok, {:volume, pow10to(n-6), "l"}}
  defp decode_vif_primary(<<_::1, 0b0011::4,  n::3>>), do: {:ok, {:mass, pow10to(n-6), "kg"}}
  defp decode_vif_primary(<<_::1, 0b01000::5, n::2>>), do: {:ok, {:on_time, nil, on_time_unit(n)}} # how long has the meter been powered
  defp decode_vif_primary(<<_::1, 0b01001::5, n::2>>), do: {:ok, {:operating_time, nil, on_time_unit(n)}} # how long has the meter been accumulating
  defp decode_vif_primary(<<_::1, 0b0101::4,  n::3>>), do: {:ok, {:energy, pow10to(n-3), "W"}}
  defp decode_vif_primary(<<_::1, 0b0110::4,  n::3>>), do: {:ok, {:energy, pow10to(n), "kJ/h"}}
  defp decode_vif_primary(<<_::1, 0b0111::4,  n::3>>), do: {:ok, {:volume_flow, pow10to(n-6), "l/h"}}
  defp decode_vif_primary(<<_::1, 0b1000::4,  n::3>>), do: {:ok, {:volume_flow_ext, pow10to(n-7), "l/min"}}
  defp decode_vif_primary(<<_::1, 0b1001::4,  n::3>>), do: {:ok, {:volume_flow_ext, pow10to(n-9), "ml/s"}}
  defp decode_vif_primary(<<_::1, 0b1010::4,  n::3>>), do: {:ok, {:mass_flow, pow10to(n-3), "kg/h"}}
  defp decode_vif_primary(<<_::1, 0b10110::5, n::2>>), do: {:ok, {:flow_temperature, pow10to(n-3), "°C"}}
  defp decode_vif_primary(<<_::1, 0b10111::5, n::2>>), do: {:ok, {:return_temperature, pow10to(n-3), "°C"}}
  defp decode_vif_primary(<<_::1, 0b11000::5, n::2>>), do: {:ok, {:temperature_difference, pow10to(n-3), "mK"}}
  defp decode_vif_primary(<<_::1, 0b11001::5, n::2>>), do: {:ok, {:external_temperature, pow10to(n-3), "°C"}}
  defp decode_vif_primary(<<_::1, 0b11010::5, n::2>>), do: {:ok, {:pressure, pow10to(n-3), "mbar"}}
  # Timestamp VIFs. these are annoying because their interpretation depends on the Data Field in the DIF as well.
  # we generalise here, because we can infer the correct data type based on the coding when we decode (the size differs)
  # TYPE: Date. Data field 0b0010, type G
  defp decode_vif_primary(<<_::1, 0b1101100::7>>),     do: {:ok, {:date, nil, ""}}
  # TYPE: Date+Time.
  # - Data field 0b0100, type F
  # - Data field 0b0011, type J (only time, but we still just collapse it into :datetime because we can't tell at this point.
  # - Data field 0b0110, type I
  # - Data field 0b1101, type M (LVAR)
  defp decode_vif_primary(<<_::1, 0b1101101::7>>),     do: {:ok, {:datetime, nil, ""}}

  defp decode_vif_primary(<<_::1, 0b1101110::7>>),     do: {:ok, {:units_for_hca, nil, ""}}
  defp decode_vif_primary(<<_::1, 0b1101111::7>>),     do: {:error, {:reserved, "VIF 0b1101111 reserved for future use"}}
  defp decode_vif_primary(<<_::1, 0b11100::5, n::2>>), do: {:ok, {:averaging_duration, nil, on_time_unit(n)}}
  defp decode_vif_primary(<<_::1, 0b11101::5, n::2>>), do: {:ok, {:actuality_duration, nil, on_time_unit(n)}}
  defp decode_vif_primary(<<_::1, 0b1111000::7>>),     do: {:ok, {:fabrication_no, nil, ""}}
  defp decode_vif_primary(<<_::1, 0b1111001::7>>),     do: {:ok, {:enhanced_identification, nil, ""}}
  defp decode_vif_primary(<<_::1, 0b1111010::7>>),     do: {:ok, {:address, nil, ""}}

  defp decode_vif_fd(vif) do
    raise "decoding from VIF linear extension table 0xFD not implemented"
  end

  defp decode_vif_fb(vif) do
    raise "decoding from VIF linear extension table 0xFB not implemented"
  end

  # collect vif and vife bytes and return them and the rest of the binary.
  @spec collect_vifs(binary()) :: {[binary()], binary()}
  defp collect_vifs(<<byte::binary-size(1), rest::binary>>) do
    case byte do
      <<0::1, _::7>> ->
        {[byte], rest}
      <<1::1, _::7>> ->
        {tail, rest} = collect_vifs(rest)
        {[byte|tail], rest}
    end
  end

  defp on_time_unit(0b00), do: "seconds"
  defp on_time_unit(0b01), do: "minutes"
  defp on_time_unit(0b10), do: "hours"
  defp on_time_unit(0b11), do: "days"

  defp u8_to_hex(u) when u >= 0 and u <= 255, do: "0x#{Integer.to_string(u, 16)}"
end
