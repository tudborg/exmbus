defmodule Exmbus.Crypto do
  @moduledoc """
  Wraps the crypto functions used in the Exmbus library.
  """

  @type crypto_error_tag :: :badarg | :notsup | :error
  @type crypto_error_c_fileinfo :: term()
  @type crypto_error_description :: String.t()
  @type crypto_error ::
          {crypto_error_tag(), crypto_error_c_fileinfo(), crypto_error_description()}

  # is really :crypto.cipher_iv() but that type is not exported
  @type cipher_iv :: atom()
  # is really :crypto.cipher_no_iv() but that type is not exported
  @type cipher_no_iv :: atom()
  # is really :crypto.crypto_opts() but that type is not exported
  @type crypto_opts :: [any()]

  @doc """
  Wraps the crypto_one_time function from the crypto module, catching errors and returning them as {:error, {:crypto_error, e}} tuples.
  We do this to prevent a bad key from crashing the parse.
  """
  @spec crypto_one_time(
          cipher :: cipher_iv(),
          key :: iodata(),
          iv :: iodata(),
          data :: iodata(),
          flag_or_options :: crypto_opts() | boolean()
        ) :: {:ok, binary} | {:error, crypto_error()}
  def crypto_one_time(cipher, key, iv, data, flag_or_options) do
    try do
      {:ok, :crypto.crypto_one_time(cipher, key, iv, data, flag_or_options)}
    catch
      :error, {_tag, _c_file_info, _description} = e -> {:error, e}
    end
  end

  @doc """
  Wraps the crypto_one_time function from the crypto module, just like crypto_one_time/5, but without the IV.
  """
  @spec crypto_one_time(
          cipher :: cipher_no_iv(),
          key :: iodata(),
          data :: iodata(),
          flag_or_options :: crypto_opts() | boolean()
        ) :: {:ok, binary} | {:error, crypto_error()}
  def crypto_one_time(cipher, key, data, flag_or_options) do
    try do
      {:ok, :crypto.crypto_one_time(cipher, key, data, flag_or_options)}
    catch
      :error, {_tag, _c_file_info, _description} = e -> {:error, {:crypto_error, e}}
    end
  end

  @doc """
  Runs the KDF-A key derivation function as described in EN 13757-7:2018 (9.6.2)
  """
  @spec kdf_a(
          direction :: :from_meter | :to_meter,
          mode :: :enc | :mac,
          counter :: integer(),
          meter_id :: binary(),
          message_key :: binary()
        ) :: {:ok, binary()} | {:error, reason :: any()}
  def kdf_a(direction, mode, counter, meter_id, message_key)
      when is_number(counter) and is_binary(meter_id) and is_binary(message_key) do
    # DC is described as follows:
    # | Sequence | Applicable key                                   |
    # |----------|--------------------------------------------------|
    # |     0x00 | Encryption from the meter (Kenc)                 |
    # |     0x01 | MAC from the meter (Kmac)                        |
    # |     0x10 | Encryption from the communication partner (Lenc) |
    # |     0x11 | MAC from the communication partner (Lmac)        |
    dc =
      case {direction, mode} do
        {:from_meter, :enc} -> 0x00
        {:from_meter, :mac} -> 0x01
        {:to_meter, :enc} -> 0x10
        {:to_meter, :mac} -> 0x11
      end

    data =
      <<dc, counter::little-size(32), meter_id::binary, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07>>

    case :crypto.mac(:cmac, :aes_128_cbc, message_key, data) do
      binary when is_binary(binary) -> {:ok, binary}
    end
  end

  def kdf_a!(direction, mode, counter, meter_id, message_key) do
    case kdf_a(direction, mode, counter, meter_id, message_key) do
      {:ok, key} -> key
    end
  end
end
