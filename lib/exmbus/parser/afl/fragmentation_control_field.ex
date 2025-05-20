defmodule Exmbus.Parser.Afl.FragmentationControlField do
  @moduledoc """
  AFL Fragmentation Control Field (FCL) as per EN 13757-7:2018

  | Bit      | Field Name | Description                                      |
  |----------|------------|--------------------------------------------------|
  | 15       | RES        | Reserved (`0b0` by default)                      |
  | 14       | MF         | More-Fragments                                   |
  |          |            | `0b0` This is the last fragment                  |
  |          |            | `0b1` More fragments are following               |
  | 13       | MCLP       | Message Control in this Fragment Present *a      |
  | 12       | MLP        | Message Length in this Fragment Present *a       |
  | 11       | MCRP       | Message counter in this Fragment Present *a      |
  | 10       | MACP       | MAC in this Fragment Present *a                  |
  | 9        | KIP        | Key Information in this Fragment Present *a      |
  | 8        | RES        | Reserved (`0b0` by default)                      |
  | 7 to 0   | FID        | Fragment-ID                                      |

  - `*a` 0 = field is not present; 1 = field is present

  The Fragment ID is used for the identification of each single fragment of a long message.
  Set FID to 1 for the first fragment of a fragmented message. FID shall increment with each fragment. The FID shall never roll over. For unfragmented messages the FID shall be set to 0.

  """

  defstruct [
    # more fragments?
    more_fragments?: nil,
    # Message Control (MCL) present?
    message_control_present?: nil,
    # Message Length (ML) present?
    message_length_present?: nil,
    # Message Counter (MCR) present?
    message_counter_present?: nil,
    # Message Authentication Code (MAC) present?
    mac_present?: nil,
    # Key Information (KI) present?
    key_information_present?: nil,
    # fragment ID (FID)
    # A fragment ID of 0x00 indicates that the message is not fragmented.
    # The first fragment of a message has the fragment ID 0x01.
    fragment_id: nil
  ]

  @doc "If the fragment ID is greater than 0, the message is fragmented"
  def fragmented?(%__MODULE__{fragment_id: fid}), do: fid > 0

  @doc """
  Parses the Fragmentation Control Field (FCL) from the AFL.

  ## Examples

      iex> decode(<<0b00000000, 0b00101100>>)
      {:ok, %Exmbus.Parser.Afl.FragmentationControlField{
        more_fragments?: false,
        message_control_present?: true,
        message_length_present?: false,
        message_counter_present?: true,
        mac_present?: true,
        key_information_present?: false,
        fragment_id: 0
      }}
  """
  def decode(<<
        # fragment ID (FID)
        fragment_id::8,
        # reserved
        _::1,
        # more fragments? 1==more fragments, 0==last fragment
        more_fragments::1,
        # Message Control (MCL) present?
        message_control_present::1,
        # Message Length (ML) present?
        message_length_present::1,
        # Message Counter (MCR) present?
        message_counter_present::1,
        # Message Authentication Code (MAC) present?
        mac_present::1,
        # Key Information (KI) present?
        key_information_present::1,
        # reserved
        _::1
      >>) do
    {:ok,
     %__MODULE__{
       more_fragments?: more_fragments == 1,
       message_control_present?: message_control_present == 1,
       message_length_present?: message_length_present == 1,
       message_counter_present?: message_counter_present == 1,
       mac_present?: mac_present == 1,
       key_information_present?: key_information_present == 1,
       fragment_id: fragment_id
     }}
  end

  @doc """
  Encodes the Fragmentation Control Field (FCL) to a binary format.

  ## Examples

      iex> encode(%Exmbus.Parser.Afl.FragmentationControlField{
      ...> more_fragments?: false,
      ...> message_control_present?: true,
      ...> message_length_present?: false,
      ...> message_counter_present?: true,
      ...> mac_present?: true,
      ...> key_information_present?: false,
      ...> fragment_id: 0
      ...> })
      <<0b00000000, 0b00101100>>
  """
  def encode(%__MODULE__{} = fcl) do
    <<
      fcl.fragment_id::8,
      0::1,
      bool_to_int(fcl.more_fragments?)::1,
      bool_to_int(fcl.message_control_present?)::1,
      bool_to_int(fcl.message_length_present?)::1,
      bool_to_int(fcl.message_counter_present?)::1,
      bool_to_int(fcl.mac_present?)::1,
      bool_to_int(fcl.key_information_present?)::1,
      0::1
    >>
  end

  defp bool_to_int(true), do: 1
  defp bool_to_int(false), do: 0
end
