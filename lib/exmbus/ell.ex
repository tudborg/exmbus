defmodule Exmbus.Ell do
  @moduledoc """
  Module responsible for handling the extended link layer
  Spec taken from EN 13757-4:2019.

  See also the Exmbus.CI module.
  """

  alias Exmbus.Manufacturer
  alias Exmbus.DataType
  alias Exmbus.Tpl.Device
  alias Exmbus.CI
  alias Exmbus.Ell.CommunicationControl
  alias Exmbus.Ell.SessionNumber

  defstruct [
    communication_control: nil,
    access_no: nil,
    session_number: nil,
  ]

  # > This value of the CI-field is used if data encryption at the link layer is not used in the frame.
  # > Table 44 below, shows the complete extension block in this case.
  # Fields: CC, ACC
  def parse(<<0x8C, cc::binary-size(1), acc, rest::binary>>, opts, ctx) do
    {:ok, control} = CommunicationControl.decode(cc)
    ell = %__MODULE__{
      communication_control: control,
      access_no: acc,
    }
    CI.parse(rest, opts, [ell | ctx])
  end

  # > This value of the CI-field is used if data encryption at the link layer is used in the frame.
  # > Table 45 below, shows the complete extension block in this case.
  # Fields: CC, ACC, SN, PayloadCRC (the payload is part of encrypted)
  def parse(<<0x8D, cc::binary-size(1), acc, sn::binary-size(4), payload_crc::size(16), rest::binary>>, opts, ctx) do
    {:ok, control} = CommunicationControl.decode(cc)
    {:ok, session_number} = SessionNumber.decode(sn)

    ell = %__MODULE__{
      communication_control: control,
      access_no: acc,
      session_number: session_number,
    }
    with {:ok, plain} <- decrypt_and_verify(<<payload_crc::size(16), rest::binary>>, opts, [ell | ctx]) do
      CI.parse(plain, opts, [ell | ctx])
    end
  end

  # > This value of the CI-field is used if data encryption at the link layer is not used in the frame.
  # > This extended link layer specifies the receiver address.
  # > Table 46 below shows the complete extension block in this case.
  # Fields: CC, ACC, M2, A2
  def parse(<<0x8E, _cc::binary-size(1), _acc, _m2::binary-size(2), _a2::binary-size(6), _rest::binary>>, _opts, _ctx) do
    raise "TODO: ELL III"
  end

  # > This value of the CI-field is used if data encryption at the link layer is used in the frame.
  # > This extended link layer specifies the receiver address.
  # > Table 47 below shows the complete extension block in this case.
  # Fields: CC, ACC, M2, A2, SN, PayloadCRC
  def parse(<<0x8F, _cc::binary-size(1), _acc, _m2::binary-size(2), _a2::binary-size(6), _sn::binary-size(4), _payload_crc::binary-size(2), _rest::binary>>, _opts, _ctx) do
    raise "TODO: ELL IV"
  end

  # > The variable Extended Link Layer allows to select optional ELL fields separately.
  # > The shadowed rows of Table 48 shall always be present.
  # > The other fields are optional and can be selected in case they are needed.
  # > The table defines the ordering of the fields.
  def parse(<<0x86, _rest::binary>>, _opts, _ctx) do
    raise "TODO: ELL V"
  end

  defp decrypt_and_verify(<<payload_crc::little-size(16), plain::binary>>, _opts, [%__MODULE__{session_number: %{encryption: :none}} | _]) do
    # encryption mode is none, so we just need to verify the payload crc
    # assuming that this was a CI=8D or CI=8F
    verify_crc(payload_crc, plain)
  end

  defp decrypt_and_verify(bin, opts, [%__MODULE__{session_number: %{encryption: :aes_128_ctr}}=ell | _]=ctx) do
    frame_number = 0
    block_counter = 0

    # 13.2.12.4Communication Control Field (CC-field)
    # The value is retrieved from the Extended Link Layer, see 13.2.7.
    # The bits of the Communication Control Field handled by the repeater
    # (R-field and H-field) are always set to zero in the Initial Counter Block.
    cc_for_icb = %{ell.communication_control | hop_count: false, repeated_access: false}

    {:ok, identification_bytes} = identity_from_ctx(ctx)
    {:ok, cc_bytes} = CommunicationControl.encode(cc_for_icb)
    {:ok, sn_bytes} = SessionNumber.encode(ell.session_number)

    # initial counter block
    icb = <<
      # identification_bytes is
      # manufacturer + serial + device + version (as in the Wmbus DLL)
      identification_bytes::binary,
      cc_bytes::binary,
      sn_bytes::binary,
      frame_number::little-size(16),
      block_counter
    >>

    with {:ok, keys} <- Exmbus.Key.get(opts, ctx) do
      try_decrypt_and_verify(bin, icb, ctx, keys, [])
    else
      {:error, e} ->
        {:error, e, ctx}
    end
  end

  # no keys, no errors (so no keys was tried)
  defp try_decrypt_and_verify(_bin, _icb, ctx, [], []) do
    {:error, {:ell_decryption_failed, :no_keys_available}, ctx}
  end
  defp try_decrypt_and_verify(_bin, _icb, ctx, [], error_acc) do
    {:error, {:ell_decryption_failed, Enum.reverse(error_acc)}, ctx}
  end
  defp try_decrypt_and_verify(bin, icb, ctx, [key | keys], error_acc) do
    with {:ok, <<payload_crc::little-size(16), rest::binary>>} <- decrypt_aes(bin, icb, key),
         {:ok, plain} = verify_crc(payload_crc, rest) do
      {:ok, plain}
    else
      {:error, reason} -> try_decrypt_and_verify(bin, icb, ctx, keys, [%{key: key, reason: reason} | error_acc])
    end
  end

  # Try to decrypt bin with key.
  defp decrypt_aes(bin, icb, key) do
    result = :crypto.stream_init(:aes_ctr, key, icb) |> :crypto.stream_decrypt(bin)
    case result do
      {_newState, plain} -> {:ok, plain}
      :run_time_error -> {:error, :run_time_error}
    end
  end

  defp verify_crc(payload_crc, plain) when is_integer(payload_crc) and is_binary(plain) do
    case Exmbus.crc!(plain) do
      ^payload_crc ->
        {:ok, plain}
      bad_payload_crc ->
        {:error, {:bad_payload_crc, bad_payload_crc}}
    end
  end

  defp identity_from_ctx([%Exmbus.Dll.Wmbus{manufacturer: m, identification_no: i, version: v, device: d} | _]) do
    {:ok, m_bytes} = Manufacturer.encode(m)
    {:ok, i_bytes} = DataType.encode_type_a(i, 32)
    {:ok, d_byte} = Device.encode(d)
    {:ok, <<m_bytes::binary, i_bytes::binary, v, d_byte::binary>>}
  end
  defp identity_from_ctx([_ | rest]) do
    identity_from_ctx(rest)
  end
  defp identity_from_ctx([]) do
    {:error, :could_not_find_identity}
  end


end
