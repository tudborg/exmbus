defmodule Exmbus.Parser.Dll.Mbus do
  @moduledoc """
  Data Link Layer for Mbus
  """

  alias Exmbus.Parser.Context
  alias Exmbus.Parser

  defstruct control: nil,
            address: nil

  @doc """
  Parse an mbus message
  """
  def parse(<<0x68, len, len, 0x68, rest::binary>>, opts, ctx) when byte_size(rest) == len + 2 do
    <<payload::binary-size(len), checksum, 0x16>> = rest

    # the mbus checksum is just the sum of all the payload bytes in one byte
    sum_of_payload =
      :binary.bin_to_list(payload)
      |> Enum.sum()
      |> rem(256)

    case sum_of_payload do
      ^checksum ->
        _parse(payload, opts, ctx)

      bad_checksum ->
        {:error, {:bad_mbus_checksum, bad_checksum}}
    end
  end

  defp _parse(<<c::binary-size(1), a, rest::binary>>, opts, ctx) do
    {:ok, control} = decode_c_field(c)

    dll = %__MODULE__{
      control: control,
      address: a
    }

    Parser.ci_route(rest, opts, Context.layer(ctx, :dll, dll))
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
