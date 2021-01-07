defmodule Exmbus.Dll.Wmbus do
  @moduledoc """
  Data Link Layer for WMbus
  """

  alias Exmbus.DataType
  alias Exmbus.Manufacturer
  alias Exmbus.Tpl

  defstruct [
    control: nil,
    manufacturer: nil,
    identification_no: nil,
    version: nil,
    device: nil,

    # not final
    tpl: nil,
  ]

  def decode(bin, opts \\ [])

  def decode(bin, opts) when is_list(opts) do
    decode(bin, Enum.into(opts, %{}))
  end

  def decode(<<len, rest::binary>>, %{length: true, crc: false}=opts) when byte_size(rest) == len do
    decode(rest, %{opts | length: false})
  end

  def decode(<<c::binary-size(1), man_bytes::binary-size(2), i_bytes::binary-size(4), v, d, rest::binary>>, %{length: false, crc: false}=opts) do
    {:ok, control} = decode_c_field(c)
    {:ok, identification_no, <<>>} = DataType.decode_type_a(i_bytes, 32)
    {:ok, manufacturer} = Manufacturer.decode(man_bytes)
    dll_opts = %{
      # :/ In the case of short header in TPL then encryption will need information from DLL to create IV for decryption
      dll: %{manufacturer: manufacturer, identification_no: identification_no, version: v, device: d}
    }
    case Tpl.decode(rest, Map.merge(dll_opts, opts)) do
      {:error, reason} ->
        {:error, {:tpl_decode_failed, reason}}
      {:ok, tpl} ->
        {:ok, %__MODULE__{
          control: control,
          manufacturer: manufacturer,
          identification_no: identification_no,
          version: v,
          device: d,
          tpl: tpl,
        }}
    end
  end

  # set some defaults:
  def decode(bin, %{}=opts) when not is_map_key(opts, :length), do: decode(bin, Map.put(opts, :length, true))
  def decode(bin, %{}=opts) when not is_map_key(opts, :crc), do: decode(bin, Map.put(opts, :crc, false))

  def decode_c_field(<<0::1, 1::1, _fcb::1, _fcv::1, 0x0::4>>), do: raise "SND-NKE not implemented"
  def decode_c_field(<<0::1, 1::1, _fcb::1, _fcv::1, 0x3::4>>), do: raise "SND-UD/SND-UD2 not implemented"
  def decode_c_field(<<0::1, 1::1, _fcb::1, _fcv::1, 0x4::4>>), do: {:ok, :snd_nr}
  def decode_c_field(<<0::1, 1::1, _fcb::1, _fcv::1, 0x5::4>>), do: raise "SND-UD3 not implemented"
  def decode_c_field(<<0::1, 1::1, _fcb::1, _fcv::1, 0x6::4>>), do: raise "SND-IR not implemented"
  def decode_c_field(<<0::1, 1::1, _fcb::1, _fcv::1, 0x7::4>>), do: raise "ACC-NR not implemented"
  def decode_c_field(<<0::1, 1::1, _fcb::1, _fcv::1, 0x8::4>>), do: raise "ACC-DMD not implemented"
  def decode_c_field(<<0::1, 1::1, _fcb::1, _fcv::1, 0xA::4>>), do: raise "REQ-UD1 not implemented"
  def decode_c_field(<<0::1, 1::1, _fcb::1, _fcv::1, 0xB::4>>), do: raise "REQ-UD2 not implemented"

  def decode_c_field(<<0::1, 0::1, _acd::1, _dfc::1, 0x0::4>>), do: raise "ACK not implemented"
  def decode_c_field(<<0::1, 0::1, _acd::1, _dfc::1, 0x1::4>>), do: raise "NACK not implemented"
  def decode_c_field(<<0::1, 0::1, _acd::1, _dfc::1, 0x6::4>>), do: raise "CNF-IR not implemented"
  def decode_c_field(<<0::1, 0::1, _acd::1, _dfc::1, 0x8::4>>), do: {:ok, :rsp_ud}

end
