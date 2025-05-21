defmodule Exmbus.Parser.Afl.KeyInformationField do
  @moduledoc """
  AFL Key Information Field (KIF) as per EN 13757-7:2018

  | Bit      | Field Name   | Description                                                                 |
  |----------|--------------|-----------------------------------------------------------------------------|
  | 15 to 8  | Key Version  | The Key Version identifies the applied key version, as specified in 7.7.1.  |
  | 7 to 6   | RES          | Reserved (`0b0` by default)                                                 |
  | 5 to 4   | KDF-Selection| The KDF-Selection identifies the applied Key Derivation Function, as specified in Table 25. |
  | 3 to 0   | Key ID       | The Key ID identifies the applied key, as specified in Table 24.            |

  In case of individual fragment authentication, the message key shall be applied for all fragments of the message.
  If the KI is not present, values of the configuration field in the TPL shall be used for the key selection.
  """

  defstruct [
    # Key Version
    key_version: nil,
    # KDF-Selection
    kdf_selection: nil,
    # Key ID
    key_id: nil
  ]

  def kdf(%__MODULE__{kdf_selection: kdf_selection}) do
    case kdf_selection do
      0 -> :persistent_key
      1 -> :kdf_a
      n -> {:reserved, n}
    end
  end

  @doc """
  Parses the Key Information Field (KI) from the AFL.

  ## Examples

      iex> decode(<<0b00000000, 0b00000000>>)
      {:ok, %Exmbus.Parser.Afl.KeyInformationField{
        key_version: 0,
        kdf_selection: 0,
        key_id: 0
      }}
  """
  def decode(<<
        # Key Version
        key_version::8,
        # reserved
        _::2,
        # KDF-Selection
        kdf_selection::2,
        # Key ID
        key_id::4
      >>) do
    {:ok, %__MODULE__{key_version: key_version, kdf_selection: kdf_selection, key_id: key_id}}
  end

  @doc """
  Encode the Key Information Field (KI) to binary.

  ## Examples

      iex> encode(%Exmbus.Parser.Afl.KeyInformationField{
      ...>   key_version: 0,
      ...>   kdf_selection: 0,
      ...>   key_id: 0
      ...> })
      <<0x00, 0x00>>

      iex> encode(nil)
      <<>>
  """
  def encode(%__MODULE__{
        key_version: key_version,
        kdf_selection: kdf_selection,
        key_id: key_id
      }) do
    <<key_version::8, 0::2, kdf_selection::2, key_id::4>>
  end

  def encode(nil), do: <<>>
end
