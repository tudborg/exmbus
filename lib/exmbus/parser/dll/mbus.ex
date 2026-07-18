defmodule Exmbus.Parser.Dll.Mbus do
  @moduledoc """
  Data Link Layer for Mbus
  """

  alias Exmbus.Parser.Context

  defstruct control: nil,
            address: nil

  @doc """
  Parse an mbus message
  """
  def parse(%{bin: <<0x68, len, len, 0x68, rest::binary>>} = ctx)
      when byte_size(rest) == len + 2 do
    <<payload::binary-size(len), checksum, 0x16>> = rest

    # the mbus checksum is just the sum of all the payload bytes in one byte
    sum_of_payload =
      :binary.bin_to_list(payload)
      |> Enum.sum()
      |> rem(256)

    case sum_of_payload do
      ^checksum ->
        _parse(payload, ctx)

      bad_checksum ->
        {:halt, Context.add_error(ctx, {:bad_mbus_checksum, bad_checksum})}
    end
  end

  def parse(ctx), do: {:halt, Context.add_error(ctx, {:invalid_dll, :mbus})}

  defp _parse(<<c::binary-size(1), a, rest::binary>>, ctx) do
    with {:ok, control} <- decode_c_field(c) do
      dll = %__MODULE__{
        control: control,
        address: a
      }

      {:next, %{ctx | dll: dll, bin: rest}}
    else
      {:error, reason} -> {:halt, Context.add_error(ctx, reason)}
    end
  end

  def unparse(%{dll: nil} = ctx) do
    {:next, ctx}
  end

  def unparse(%{dll: %__MODULE__{}} = ctx) do
    {:halt, Context.add_error(ctx, :mbus_unparse_not_implemented)}
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
end
