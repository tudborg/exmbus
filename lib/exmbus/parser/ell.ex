defmodule Exmbus.Parser.Ell do
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

  @doc """
  Parses an extended link layer and adds it to the parse context.

  In contrast to `parse/1`, this function will not fail if the data
  doesn't contain an ELL. Instead, it will assign a `%None{}` struct
  to the ell context field.
  """
  def maybe_parse(%{} = ctx) do
    case parse(ctx) do
      {:abort, %Context{errors: [{_handler_func, {:ci_not_ell, _ci}} | _]}} ->
        {:continue, Context.merge(ctx, ell: %None{})}

      {:abort, ctx} ->
        {:abort, ctx}

      {:continue, ctx} ->
        {:continue, ctx}
    end
  end

  # > This value of the CI-field is used if data encryption at the link layer is not used in the frame.
  # > Table 44 below, shows the complete extension block in this case.
  # Fields: CC, ACC
  def parse(%{bin: <<0x8C, cc::binary-size(1), acc, rest::binary>>} = ctx) do
    {:ok, control} = CommunicationControl.decode(cc)

    ell = %Unencrypted{
      communication_control: control,
      access_no: acc
    }

    {:continue, Context.merge(ctx, ell: ell, bin: rest)}
  end

  # > This value of the CI-field is used if data encryption at the link layer is used in the frame.
  # > Table 45 below, shows the complete extension block in this case.
  # Fields: CC, ACC, SN, PayloadCRC (the payload is part of encrypted)
  def parse(
        %{
          bin:
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

    {:continue, Context.merge(ctx, ell: ell, bin: <<payload_crc::size(16), rest::binary>>)}
  end

  # > This value of the CI-field is used if data encryption at the link layer is not used in the frame.
  # > This extended link layer specifies the receiver address.
  # > Table 46 below shows the complete extension block in this case.
  # Fields: CC, ACC, M2, A2
  def parse(%{
        bin:
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
        bin:
          <<0x8F, _cc::binary-size(1), _acc, _m2::binary-size(2), _a2::binary-size(6),
            _sn::binary-size(4), _payload_crc::binary-size(2), _rest::binary>>
      }) do
    raise "TODO: ELL IV"
  end

  # > The variable Extended Link Layer allows to select optional ELL fields separately.
  # > The shadowed rows of Table 48 shall always be present.
  # > The other fields are optional and can be selected in case they are needed.
  # > The table defines the ordering of the fields.
  def parse(%{bin: <<0x86, _rest::binary>>}) do
    raise "TODO: ELL V"
  end

  def parse(%{bin: <<ci, _rest::binary>>} = ctx) do
    {:abort, Context.add_error(ctx, {:ci_not_ell, ci})}
  end

  defdelegate maybe_decrypt_bin(ctx), to: Encrypted
  defdelegate decrypt_bin(ctx), to: Encrypted
end
