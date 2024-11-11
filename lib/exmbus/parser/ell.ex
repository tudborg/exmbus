defmodule Exmbus.Parser.Ell do
  @behaviour Exmbus.Parser.ParseBehaviour
  @moduledoc """
  Module responsible for handling the extended link layer
  Spec taken from EN 13757-4:2019.

  See also the Exmbus.Parser.CI module.
  """

  alias Exmbus.Parser.Context
  alias Exmbus.Parser.Ell.CommunicationControl
  alias Exmbus.Parser.Ell.SessionNumber
  alias Exmbus.Parser.Ell.None
  alias Exmbus.Parser.Ell.Encrypted
  alias Exmbus.Parser.Ell.Unencrypted

  # > This value of the CI-field is used if data encryption at the link layer is not used in the frame.
  # > Table 44 below, shows the complete extension block in this case.
  # Fields: CC, ACC
  def parse(%{rest: <<0x8C, cc::binary-size(1), acc, rest::binary>>} = ctx) do
    {:ok, control} = CommunicationControl.decode(cc)

    ell = %Unencrypted{
      communication_control: control,
      access_no: acc
    }

    {:continue, Context.merge(ctx, ell: ell, rest: rest)}
  end

  # > This value of the CI-field is used if data encryption at the link layer is used in the frame.
  # > Table 45 below, shows the complete extension block in this case.
  # Fields: CC, ACC, SN, PayloadCRC (the payload is part of encrypted)
  def parse(
        %{
          rest:
            <<0x8D, cc::binary-size(1), acc, sn::binary-size(4), payload_crc::size(16),
              rest::binary>>
        } = ctx
      ) do
    {:ok, control} = CommunicationControl.decode(cc)
    {:ok, session_number} = SessionNumber.decode(sn)

    ell = %Encrypted{
      communication_control: control,
      access_no: acc,
      session_number: session_number
    }

    {:continue, Context.merge(ctx, ell: ell, rest: <<payload_crc::size(16), rest::binary>>)}
  end

  # > This value of the CI-field is used if data encryption at the link layer is not used in the frame.
  # > This extended link layer specifies the receiver address.
  # > Table 46 below shows the complete extension block in this case.
  # Fields: CC, ACC, M2, A2
  def parse(%{
        rest:
          <<0x8E, _cc::binary-size(1), _acc, _m2::binary-size(2), _a2::binary-size(6),
            _rest::binary>>
      }) do
    raise "TODO: ELL III"
  end

  # > This value of the CI-field is used if data encryption at the link layer is used in the frame.
  # > This extended link layer specifies the receiver address.
  # > Table 47 below shows the complete extension block in this case.
  # Fields: CC, ACC, M2, A2, SN, PayloadCRC
  def parse(%{
        rest:
          <<0x8F, _cc::binary-size(1), _acc, _m2::binary-size(2), _a2::binary-size(6),
            _sn::binary-size(4), _payload_crc::binary-size(2), _rest::binary>>
      }) do
    raise "TODO: ELL IV"
  end

  # > The variable Extended Link Layer allows to select optional ELL fields separately.
  # > The shadowed rows of Table 48 shall always be present.
  # > The other fields are optional and can be selected in case they are needed.
  # > The table defines the ordering of the fields.
  def parse(%{rest: <<0x86, _rest::binary>>}) do
    raise "TODO: ELL V"
  end

  # When the CI is not an ELL CI, we set the ELL to none and continue
  def parse(%{rest: _} = ctx) do
    {:continue, Context.merge(ctx, ell: %None{})}
  end
end
