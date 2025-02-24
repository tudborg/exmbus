defmodule Exmbus.Parser.Dll.Wmbus do
  @moduledoc """
  Data Link Layer for WMbus
  """
  alias Exmbus.Parser.Context
  alias Exmbus.Parser.DataType
  alias Exmbus.Parser.Manufacturer
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
    {:error, :frame_format_b_not_implemented}
  end

  defp validate_frame_format_b(bin) do
    {:error, {:not_valid_frame_format_b, bin}}
  end

  @doc """
  Parse a wmbus message
  """

  # Expect length and crc in frame: Check CRC and length match.
  # Be aware of Frame format A vs B
  # We generally receive frames with the CRC stripped,
  # so I've not yet needed to _actually_ implement this function head.
  def parse(%{bin: <<_len, _rest::binary>>, opts: %{length: true, crc: true}} = ctx) do
    case validate_frame_format_b(ctx.bin) do
      {:ok, valid_bin} ->
        %{ctx | bin: valid_bin}
        |> Context.merge_opts(%{length: false, crc: false})
        |> parse()

      {:error, {:not_valid_frame_format_b, _}} ->
        case validate_frame_format_a(ctx.bin) do
          {:ok, valid_bin} ->
            %{ctx | bin: valid_bin}
            |> Context.merge_opts(%{length: false, crc: false})
            |> parse()

          {:error, {:not_valid_frame_format_a, _}} ->
            {:halt, Context.add_error(ctx, {:bad_length_or_crc, ctx.bin})}
        end
    end
  end

  # length is set, but CRC isn't. Assume a pre-process step has checked and removed CRC.
  # But length is still here, which is weird because the length depends on the frame format (A or B) which can
  # either be including or excluding CRC.
  # At this point, we don't know the frame format, so we can't validate the length.
  # There is a chance that this isn't wmbus length but some other application's length.
  # A sane assumption is that length describes the length of the `rest`,
  # But it could also be the length of the wmbus frame, and some additional data remains at the end.
  # (e.g. RSSI appended at the end)
  def parse(
        %{bin: <<len, rest::binary-size(len), tail::binary>>, opts: %{length: true, crc: false}} =
          ctx
      ) do
    ctx = Context.merge_opts(%{ctx | bin: rest}, %{length: false})

    case tail do
      <<>> -> parse(ctx)
      tail -> parse(Context.add_warning(ctx, {:trailing_data, tail}))
    end
  end

  def parse(
        %{
          bin:
            <<c::binary-size(1), man_bytes::binary-size(2), i_bytes::binary-size(4), v,
              d::binary-size(1), rest::binary>>,
          opts: %{length: false, crc: false}
        } = ctx
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

    {:next, %{ctx | bin: rest, dll: dll}}
  end

  # set some defaults.
  # maybe move this out of the core parsing logic.
  def parse(%{opts: opts} = ctx) when not is_map_key(opts, :length),
    do: parse(%{ctx | opts: Map.put(opts, :length, true)})

  def parse(%{opts: opts} = ctx) when not is_map_key(opts, :crc),
    do: parse(%{ctx | opts: Map.put(opts, :crc, false)})

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
