defmodule Exmbus.Parser.Afl.MessageControlField do
  @moduledoc """
  AFL Message Control Field (MCL) as per EN 13757-7:2018


  | Bit | Field Name | Description                                      |
  |-----|------------|--------------------------------------------------|
  | 7   | RES        | Reserved (`0b0` by default)                      |
  | 6   | MLMP       | Message Length in Message Present *a             |
  | 5   | MCMP       | Message counter in Message Present *a            |
  | 4   | KIMP       | Key Information in Message Present *a            |
  | 3   | AT         |                                                  |
  | 2   | AT         | Authentication-Type (see Table 6)                |
  | 1   | AT         |                                                  |
  | 0   | AT         |                                                  |

  - `*a` 0 = field is not present; 1 = field is present

  The bits 4 to 7 in the AFL.MCL field define the presence of additional fields in the message.

  > If the AFL.MCL field is used it always shall be present in the first fragment. It shall not be present in any following fragments of the same message.

  That is, we can expect the MCL field in fragment_id == 0x01.

  """

  defstruct [
    # Message Length in Message Present
    message_length_present?: nil,
    # Message counter in Message Present
    message_counter_present?: nil,
    # Key Information in Message Present
    key_information_present?: nil,
    # Authentication-Type (AT)
    authentication_type: nil
  ]

  @doc """
  Returns the authentication type and it's length
  """
  def authentication_type(%__MODULE__{authentication_type: 0}), do: {:none, 0}
  def authentication_type(%__MODULE__{authentication_type: 3}), do: {:aes_cmac_128, 2}
  def authentication_type(%__MODULE__{authentication_type: 4}), do: {:aes_cmac_128, 4}
  def authentication_type(%__MODULE__{authentication_type: 5}), do: {:aes_cmac_128, 8}
  def authentication_type(%__MODULE__{authentication_type: 6}), do: {:aes_cmac_128, 12}
  def authentication_type(%__MODULE__{authentication_type: 7}), do: {:aes_cmac_128, 16}
  def authentication_type(%__MODULE__{authentication_type: 8}), do: {:aes_gmac_128, 12}
  def authentication_type(%__MODULE__{authentication_type: 9}), do: {:aes_gmac_128, 16}
  def authentication_type(%__MODULE__{authentication_type: n}), do: {{:reserved, n}, 0}

  @doc """
  Parses the Message Control Field (MCL) from the AFL.

  ## Examples

      iex> decode(<<0b00000000>>)
      {:ok, %Exmbus.Parser.Afl.MessageControlField{
        message_length_present?: false,
        message_counter_present?: false,
        key_information_present?: false,
        authentication_type: 0
      }}
  """
  def decode(<<
        # reserved
        _::1,
        # Message Length in Message Present
        mlmp::1,
        # Message counter in Message Present
        mcmp::1,
        # Key Information in Message Present
        kimp::1,
        # Authentication-Type (AT)
        at::4
      >>) do
    {:ok,
     %__MODULE__{
       message_length_present?: mlmp == 1,
       message_counter_present?: mcmp == 1,
       key_information_present?: kimp == 1,
       authentication_type: at
     }}
  end

  @doc """
  Encodes the Message Control Field (MCL) to a binary.

  ## Examples

      iex> encode(%Exmbus.Parser.Afl.MessageControlField{
      ...>   message_length_present?: false,
      ...>   message_counter_present?: false,
      ...>   key_information_present?: false,
      ...>   authentication_type: 0b0000
      ...> })
      <<0b00000000>>

      iex> encode(%Exmbus.Parser.Afl.MessageControlField{
      ...>   message_length_present?: true,
      ...>   message_counter_present?: true,
      ...>   key_information_present?: true,
      ...>   authentication_type: 0b0011
      ...> })
      <<0b01110011>>

      iex> encode(nil)
      <<>>
  """
  def encode(%__MODULE__{
        message_length_present?: mlmp,
        message_counter_present?: mcmp,
        key_information_present?: kimp,
        authentication_type: at
      }) do
    <<0::1, bool_to_int(mlmp)::1, bool_to_int(mcmp)::1, bool_to_int(kimp)::1, at::4>>
  end

  def encode(nil), do: <<>>

  defp bool_to_int(true), do: 1
  defp bool_to_int(false), do: 0
end
