defmodule Exmbus.Parser.Dll.Wmbus do
  @moduledoc """
  Data Link Layer for WMbus
  """
  alias Exmbus.Parser.Context
  alias Exmbus.Parser.IdentificationNo
  alias Exmbus.Parser.Manufacturer
  alias Exmbus.Parser.Tpl.Device

  defstruct control: nil,
            manufacturer: nil,
            identification_no: nil,
            version: nil,
            device: nil

  @doc """
  Parse a wmbus message
  """

  # Expect length and crc in frame: Check CRC and length match.
  # Be aware of Frame format A vs B
  # We generally receive frames with the CRC stripped,
  # so I've not yet needed to _actually_ implement this function head.
  def parse(%{bin: <<_len, _rest::binary>>, opts: %{length: true, crc: true}} = ctx) do
    {:halt, Context.add_error(ctx, {:not_implemented, :crc})}
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
    ctx = %{ctx | bin: rest}

    case tail do
      <<>> -> do_parse(ctx)
      tail -> do_parse(Context.add_warning(ctx, {:trailing_data, tail}))
    end
  end

  # when length: true, crc: false, but the bin doesn't contain the expected length, we halt the parser
  def parse(%{bin: <<len, _rest::binary>>, opts: %{length: true, crc: false}} = ctx) do
    {:halt, Context.add_error(ctx, {:invalid_length, len})}
  end

  def parse(%{opts: %{length: false, crc: false}} = ctx) do
    do_parse(ctx)
  end

  # set some defaults.
  # maybe move this out of the core parsing logic.
  def parse(%{opts: opts} = ctx) when not is_map_key(opts, :length),
    do: parse(%{ctx | opts: Map.put(opts, :length, true)})

  def parse(%{opts: opts} = ctx) when not is_map_key(opts, :crc),
    do: parse(%{ctx | opts: Map.put(opts, :crc, false)})

  # parse the ctx bin, assumes length and crc has been handled and is not part of the bin anymore.
  defp do_parse(
         %{
           bin:
             <<c::binary-size(1), man_bytes::binary-size(2), i_bytes::binary-size(4), version,
               d::binary-size(1), rest::binary>>
         } = ctx
       ) do
    with {:ok, control} <- decode_c_field(c),
         {:ok, identification_no} <- IdentificationNo.decode(i_bytes),
         {:ok, manufacturer} <- Manufacturer.decode(man_bytes),
         {:ok, device} <- Device.decode(d) do
      dll = %__MODULE__{
        control: control,
        manufacturer: manufacturer,
        identification_no: identification_no,
        version: version,
        device: device
      }

      {:next, %{ctx | bin: rest, dll: dll}}
    else
      {:error, reason} ->
        {:halt, Context.add_error(ctx, reason)}
    end
  end

  defp do_parse(ctx), do: {:halt, Context.add_error(ctx, {:invalid_dll, :wmbus})}

  def unparse(%{dll: nil} = ctx) do
    {:next, ctx}
  end

  def unparse(%{dll: %__MODULE__{} = dll, opts: %{length: should_have_length?}} = ctx) do
    with {:ok, c} <- encode_c_field(dll.control),
         {:ok, man_b} <- Manufacturer.encode(dll.manufacturer),
         {:ok, id_b} <- IdentificationNo.encode(dll.identification_no),
         {:ok, d_b} <- Device.encode(dll.device) do
      bin =
        <<c::binary-size(1), man_b::binary-size(2), id_b::binary-size(4), dll.version,
          d_b::binary-size(1), ctx.bin::binary>>

      # add length if the original options had length
      bin =
        if should_have_length? do
          <<byte_size(bin), bin::binary>>
        else
          bin
        end

      {:next, %{ctx | bin: bin, dll: nil}}
    else
      {:error, reason} ->
        {:halt, Context.add_error(ctx, reason)}
    end
  end

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
    do: {:error, {:not_implemented, :snd_nke}}

  defp decode_c_field(<<0::1, 1::1, _fcb::1, _fcv::1, 0x3::4>>),
    do: {:error, {:not_implemented, :snd_ud}}

  defp decode_c_field(<<0::1, 1::1, _fcb::1, 0::1, 0x4::4>>), do: {:ok, :snd_nr}

  defp decode_c_field(<<0::1, 1::1, _fcb::1, 0::1, 0x5::4>>),
    do: {:error, {:not_implemented, :snd_ud3}}

  defp decode_c_field(<<0::1, 1::1, _fcb::1, 0::1, 0x6::4>>), do: {:ok, :snd_ir}

  defp decode_c_field(<<0::1, 1::1, _fcb::1, 0::1, 0x7::4>>),
    do: {:error, {:not_implemented, :acc_nr}}

  defp decode_c_field(<<0::1, 1::1, _fcb::1, 0::1, 0x8::4>>),
    do: {:error, {:not_implemented, :acc_dmd}}

  defp decode_c_field(<<0::1, 1::1, _fcb::1, 1::1, 0xA::4>>),
    do: {:error, {:not_implemented, :req_ud1}}

  defp decode_c_field(<<0::1, 1::1, _fcb::1, 1::1, 0xB::4>>),
    do: {:error, {:not_implemented, :req_ud2}}

  defp decode_c_field(<<0::1, 0::1, _acd::1, _dfc::1, 0x0::4>>),
    do: {:error, {:not_implemented, :ack}}

  defp decode_c_field(<<0::1, 0::1, _acd::1, _dfc::1, 0x1::4>>),
    do: {:error, {:not_implemented, :nack}}

  defp decode_c_field(<<0::1, 0::1, _acd::1, _dfc::1, 0x6::4>>),
    do: {:error, {:not_implemented, :cnf_ir}}

  defp decode_c_field(<<0::1, 0::1, _acd::1, _dfc::1, 0x8::4>>), do: {:ok, :rsp_ud}

  defp encode_c_field(:snd_nke), do: raise("SND-NKE not implemented")
  defp encode_c_field(:snd_ud), do: raise("SND-UD/SND-UD2 not implemented")
  defp encode_c_field(:snd_ud2), do: raise("SND-UD/SND-UD2 not implemented")
  defp encode_c_field(:snd_nr), do: {:ok, <<0::1, 1::1, 0::1, 0::1, 0x4::4>>}
  defp encode_c_field(:snd_ud3), do: raise("SND-UD3 not implemented")
  defp encode_c_field(:snd_ir), do: {:ok, <<0::1, 1::1, 0::1, 0::1, 0x6::4>>}
  defp encode_c_field(:acc_nr), do: raise("ACC-NR not implemented")
  defp encode_c_field(:acc_dmd), do: raise("ACC-DMD not implemented")
  defp encode_c_field(:req_ud1), do: raise("REQ-UD1 not implemented")
  defp encode_c_field(:req_ud2), do: raise("REQ-UD2 not implemented")
  defp encode_c_field(:ack), do: raise("ACK not implemented")
  defp encode_c_field(:nack), do: raise("NACK not implemented")
  defp encode_c_field(:cnf_ir), do: raise("CNF-IR not implemented")
  defp encode_c_field(:rsp_ud), do: {:ok, <<0::1, 0::1, 0::1, 0::1, 0x8::4>>}
end
