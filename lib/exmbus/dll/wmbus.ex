defmodule Exmbus.Dll.Wmbus do
  @moduledoc """
  Data Link Layer for WMbus
  """

  alias Exmbus.DataType
  alias Exmbus.Manufacturer
  alias Exmbus.CI
  alias Exmbus.Tpl.Device

  defstruct [
    control: nil,
    manufacturer: nil,
    identification_no: nil,
    version: nil,
    device: nil,
  ]

  @doc """
  Parse a wmbus message
  """
  def parse(<<len, rest::binary>>, %{length: true, crc: false}=opts, ctx) when byte_size(rest) == len do
    parse(rest, %{opts | length: false}, ctx)
  end

  def parse(<<c::binary-size(1), man_bytes::binary-size(2), i_bytes::binary-size(4), v, d::binary-size(1), rest::binary>>, %{length: false, crc: false}=opts, ctx) do
    {:ok, control} = decode_c_field(c)
    {:ok, identification_no, <<>>} = DataType.decode_type_a(i_bytes, 32)
    {:ok, manufacturer} = Manufacturer.decode(man_bytes)
    {:ok, device} = Device.decode(d)

    dll = %__MODULE__{
      control: control,
      manufacturer: manufacturer,
      identification_no: identification_no,
      version: v,
      device: device,
    }
    CI.parse(rest, opts, [dll | ctx])
  end

  # set some defaults.
  # maybe move this out of the core parsing logic.
  def parse(bin, %{}=opts, ctx) when not is_map_key(opts, :length), do: parse(bin, Map.put(opts, :length, true), ctx)
  def parse(bin, %{}=opts, ctx) when not is_map_key(opts, :crc),    do: parse(bin, Map.put(opts, :crc, false), ctx)

  @doc """
  Return the communication direction of a Wmbus struct.
  The possible values are: :to_meter, :from_meter, :both
  """
  def direction(%__MODULE__{control: :snd_nke}), do: {:ok, :to_meter}
  def direction(%__MODULE__{control: :snd_ud}),  do: {:ok, :to_meter}
  def direction(%__MODULE__{control: :snd_ud2}), do: {:ok, :to_meter}
  def direction(%__MODULE__{control: :snd_nr}),  do: {:ok, :from_meter}
  def direction(%__MODULE__{control: :snd_ud3}), do: {:ok, :to_meter}
  def direction(%__MODULE__{control: :snd_ir}),  do: {:ok, :from_meter}
  def direction(%__MODULE__{control: :acc_nr}),  do: {:ok, :from_meter}
  def direction(%__MODULE__{control: :acc_dmd}), do: {:ok, :from_meter}
  def direction(%__MODULE__{control: :req_ud1}), do: {:ok, :to_meter}
  def direction(%__MODULE__{control: :req_ud2}), do: {:ok, :to_meter}
  def direction(%__MODULE__{control: :ack}),     do: {:ok, :both}
  def direction(%__MODULE__{control: :nack}),    do: {:ok, :from_meter}
  def direction(%__MODULE__{control: :cnf_ir}),  do: {:ok, :to_meter}
  def direction(%__MODULE__{control: :rsp_ud}),  do: {:ok, :from_meter}

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
