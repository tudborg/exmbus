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
  def parse(<<0x8D, cc::binary-size(1), acc, sn::binary-size(4), payload_crc::binary-size(2), rest::binary>>, opts, ctx) do
    {:ok, control} = CommunicationControl.decode(cc)
    {:ok, session_number} = SessionNumber.decode(sn)

    ell = %__MODULE__{
      communication_control: control,
      access_no: acc,
      session_number: session_number,
    }
    with {:ok, plain} <- decrypt(<<payload_crc::binary, rest::binary>>, opts, [ell | ctx]) do
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



  defp decrypt(bin, opts, [%__MODULE__{}=ell | _]=ctx) do
    frame_number = 0
    block_counter = 0

    {:ok, identification_bytes} = identity_from_ctx(ctx)
    {:ok, cc_bytes} = CommunicationControl.encode(ell.communication_control)
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

    case Exmbus.Key.from_options(opts, ctx) do
      # when we find at least one key, try the first one (TODO, try all)
      {:ok, [aes_key_bytes | _]} ->
        {{_, _}, <<payload_crc::little-size(16), plain::binary>>} =
          :crypto.stream_init(:aes_ctr, aes_key_bytes, icb)
          |> :crypto.stream_decrypt(bin)

        case CRC.crc(:crc_16_en_13757, plain) do
          ^payload_crc ->
            {:ok, plain}
          bad_payload_crc ->
            {:error, {:decryption_failed, {:bad_payload_crc, bad_payload_crc}}, ctx}
        end
      # when we find no keys, return :decryption_failed
      {:ok, []} ->
        {:error, {:decryption_failed, :key_not_found}, ctx}
    end

  end

  defp identity_from_ctx([%Exmbus.Dll.Wmbus{manufacturer: m, identification_no: i, version: v, device: d} | _]) do
    {:ok, m_bytes} = Manufacturer.encode(m)
    {:ok, i_bytes} = DataType.encode_type_a(i, 32)
    d_byte = Device.encode(d)
    {:ok, <<m_bytes::binary, i_bytes::binary, v, d_byte::binary>>}
  end
  defp identity_from_ctx([_ | rest]) do
    identity_from_ctx(rest)
  end
  defp identity_from_ctx([]) do
    {:error, :could_not_find_identity}
  end


end
