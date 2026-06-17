defmodule Exmbus.Parser.Ell.UnencryptedWithReceiver do
  @moduledoc """
  This module represents an unencrypted ELL layer from EN 13757-4:2019

  This is used if data encryption at the link layer is not used in the frame.
  This extended link layer specifies the receiver address.
  Table 46 shows the complete extension block in this case.
  """
  alias Exmbus.Parser.Ell.CommunicationControl
  alias Exmbus.Parser.Identity

  defstruct communication_control: nil,
            access_no: nil,
            receiver: nil

  def decode(<<cc::binary-size(1), acc, m2::binary-size(2), a2::binary-size(6)>>) do
    {:ok, control} = CommunicationControl.decode(cc)

    with {:ok, receiver} <- Identity.decode(<<m2::binary, a2::binary>>) do
      {:ok,
       %__MODULE__{
         communication_control: control,
         access_no: acc,
         receiver: receiver
       }}
    end
  end

  def encode(%__MODULE__{communication_control: control, access_no: acc, receiver: receiver}) do
    with {:ok, cc} <- CommunicationControl.encode(control),
         {:ok, receiver_bin} <- Identity.encode(receiver) do
      {:ok, <<cc::binary-size(1), acc, receiver_bin::binary-size(8)>>}
    end
  end
end
