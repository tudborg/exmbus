defmodule Exmbus.Parser.Dll.Wmbus do
  @moduledoc """
  Data Link Layer for WMbus
  """

  alias Exmbus.Parser.DataType
  alias Exmbus.Parser.Manufacturer
  alias Exmbus.Parser.CI
  alias Exmbus.Parser.Tpl.Device

  defstruct control: nil,
            manufacturer: nil,
            identification_no: nil,
            version: nil,
            device: nil

  defp validate_frame_format_a(<<_len, _rest::binary>>) do
    {:error, :frame_format_a_not_implemented}
  end

  defp validate_frame_format_b(<<len, rest::binary>>) when byte_size(rest) == len do
    raise "TODO convert to plain format (No length, no CRC) and return {:ok, plain_binary}"
  end

  defp validate_frame_format_b(bin) do
    {:error, {:not_valid_frame_format_b, bin}}
  end

  @doc """
  Parse a wmbus message
  """

  # Expect length and crc in frame: Check CRC and length match.
  # Be aware of Frame format A vs B
  def parse(<<_len, _rest::binary>> = bin, %{length: true, crc: true} = opts, ctx) do
    case validate_frame_format_b(bin) do
      {:ok, valid_bin} ->
        parse(valid_bin, %{opts | length: false, crc: false}, ctx)

      {:error, {:not_valid_frame_format_b, _}} ->
        case validate_frame_format_a(bin) do
          {:ok, valid_bin} ->
            parse(valid_bin, %{opts | length: false, crc: false}, ctx)

          {:error, {:not_valid_frame_format_a, _}} ->
            {:error, {:error, {:bad_length_or_crc, bin}}, ctx}
        end
    end
  end

  # length is set, but CRC isn't. Assume a pre-process step has checked and removed CRC.
  # But length is still here, which is weird because the length depends on the frame format (A or B) which can
  # either be including or excluding CRC.
  # At this point, we don't know the frame format, so we can't validate the length.
  # There is a chance that this isn't wmbus length but some other application's length.
  # A same assumption is that length describes the length if `rest`, but that is _an assumption!_
  # We just can't really validate the length here.
  def parse(<<len, rest::binary>>, %{length: true, crc: false} = opts, ctx) do
    if byte_size(rest) == len or Map.get(opts, :ignore_length, false) do
      parse(rest, %{opts | length: false}, ctx)
    else
      {:error, :bad_length}
    end
  end

  def parse(
        <<c::binary-size(1), man_bytes::binary-size(2), i_bytes::binary-size(4), v,
          d::binary-size(1), rest::binary>>,
        %{length: false, crc: false} = opts,
        ctx
      ) do
    {:ok, control} = decode_c_field(c)
    {:ok, identification_no, <<>>} = DataType.decode_type_a(i_bytes, 32)
    {:ok, manufacturer} = Manufacturer.decode(man_bytes)
    {:ok, device} = Device.decode(d)

    dll = %__MODULE__{
      control: control,
      manufacturer: manufacturer,
      identification_no: identification_no,
      version: v,
      device: device
    }

    CI.parse(rest, opts, [dll | ctx])
  end

  # set some defaults.
  # maybe move this out of the core parsing logic.
  def parse(bin, %{} = opts, ctx) when not is_map_key(opts, :length),
    do: parse(bin, Map.put(opts, :length, false), ctx)

  def parse(bin, %{} = opts, ctx) when not is_map_key(opts, :crc),
    do: parse(bin, Map.put(opts, :crc, false), ctx)

  @doc """
  Return the communication direction of a Wmbus struct.
  The possible values are: :to_meter, :from_meter, :both
  """
  def direction(%__MODULE__{control: :snd_nke}), do: {:ok, :to_meter}
  def direction(%__MODULE__{control: :snd_ud}), do: {:ok, :to_meter}
  def direction(%__MODULE__{control: :snd_ud2}), do: {:ok, :to_meter}
  def direction(%__MODULE__{control: :snd_nr}), do: {:ok, :from_meter}
  def direction(%__MODULE__{control: :snd_ud3}), do: {:ok, :to_meter}
  def direction(%__MODULE__{control: :snd_ir}), do: {:ok, :from_meter}
  def direction(%__MODULE__{control: :acc_nr}), do: {:ok, :from_meter}
  def direction(%__MODULE__{control: :acc_dmd}), do: {:ok, :from_meter}
  def direction(%__MODULE__{control: :req_ud1}), do: {:ok, :to_meter}
  def direction(%__MODULE__{control: :req_ud2}), do: {:ok, :to_meter}
  def direction(%__MODULE__{control: :ack}), do: {:ok, :both}
  def direction(%__MODULE__{control: :nack}), do: {:ok, :from_meter}
  def direction(%__MODULE__{control: :cnf_ir}), do: {:ok, :to_meter}
  def direction(%__MODULE__{control: :rsp_ud}), do: {:ok, :from_meter}

  defp decode_c_field(<<0::1, 1::1, _fcb::1, _fcv::1, 0x0::4>>),
    do: raise("SND-NKE not implemented")

  defp decode_c_field(<<0::1, 1::1, _fcb::1, _fcv::1, 0x3::4>>),
    do: raise("SND-UD/SND-UD2 not implemented")

  defp decode_c_field(<<0::1, 1::1, _fcb::1, 0::1, 0x4::4>>), do: {:ok, :snd_nr}
  defp decode_c_field(<<0::1, 1::1, _fcb::1, 0::1, 0x5::4>>), do: raise("SND-UD3 not implemented")
  defp decode_c_field(<<0::1, 1::1, _fcb::1, 0::1, 0x6::4>>), do: {:ok, :snd_ir}
  defp decode_c_field(<<0::1, 1::1, _fcb::1, 0::1, 0x7::4>>), do: raise("ACC-NR not implemented")
  defp decode_c_field(<<0::1, 1::1, _fcb::1, 0::1, 0x8::4>>), do: raise("ACC-DMD not implemented")
  defp decode_c_field(<<0::1, 1::1, _fcb::1, 1::1, 0xA::4>>), do: raise("REQ-UD1 not implemented")
  defp decode_c_field(<<0::1, 1::1, _fcb::1, 1::1, 0xB::4>>), do: raise("REQ-UD2 not implemented")

  defp decode_c_field(<<0::1, 0::1, _acd::1, _dfc::1, 0x0::4>>), do: raise("ACK not implemented")
  defp decode_c_field(<<0::1, 0::1, _acd::1, _dfc::1, 0x1::4>>), do: raise("NACK not implemented")

  defp decode_c_field(<<0::1, 0::1, _acd::1, _dfc::1, 0x6::4>>),
    do: raise("CNF-IR not implemented")

  defp decode_c_field(<<0::1, 0::1, _acd::1, _dfc::1, 0x8::4>>), do: {:ok, :rsp_ud}
end
