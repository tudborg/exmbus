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
end
