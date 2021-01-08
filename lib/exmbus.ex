defmodule Exmbus do
  @moduledoc """
  Documentation for `Exmbus`.
  """

  alias Exmbus.Message
  alias Exmbus.Dll.Wmbus
  alias Exmbus.Apl
  alias Exmbus.Apl.EncryptedApl

  # Try to auto-guess what type of DLL is used
  # If the signature is start,length,length,start it's probably mbus DLL
  def to_message(bin, opts \\ %{})

  def to_message(bin, opts) when is_list(opts) do
    to_message(bin, opts |> Enum.into(%{}))
  end

  def to_message(<<s, l, l, s, _::binary>>=bin, opts) when is_binary(bin) do
    raise "TODO"
  end
  # otherwise probably wmbus
  def to_message(bin, opts) when is_binary(bin) do
    case parse_wmbus(bin, opts) do
      {:ok, parsed} -> to_message(parsed, opts)
      {:error, _}=e -> e
    end
  end

  # if it's a list it's layers of mbus (already parsed)
  # if the top layer is encrypted APL we need to decrypt it if we have a key function in the opts
  def to_message([%EncryptedApl{} | _]=parsed, opts) do
    case Map.get(opts, :keyfn) do
      nil ->
        {:error, :found_encrypted_apl_but_no_keyfn_available}
      f when is_function(f) ->
        case decrypt(parsed, f, opts) do
          {:ok, plain_parsed} -> to_message(plain_parsed, opts)
          {:error, _}=e -> e
        end
    end
  end
  # If the top layer is a regular Apl then we convert to a Message
  def to_message([%Apl{} | _]=parsed, opts) do
    Message.from_parsed(parsed, opts)
  end

  def decrypt(parsed, keys_or_function) do
    decrypt(parsed, keys_or_function, %{})
  end
  def decrypt(parsed, f, opts) when is_function(f, 2) do
    case f.(parsed, opts) do
      {:ok, keys} when is_list(keys) -> decrypt(parsed, keys, opts)
      {:error, _}=e -> e
    end
  end
  def decrypt(parsed, [], _opts) do
    {:error, :no_keys_matched}
  end
  def decrypt(parsed, [key|tail], opts) do
    case EncryptedApl.decrypt(parsed, key, opts) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, {:invalid_key, _}} -> decrypt(tail, parsed, opts)
    end
  end



  def parse_wmbus(bin, opts \\ %{}) when is_list(opts) do
    parse_wmbus(bin, opts |> Enum.into(%{}))
  end
  def parse_wmbus(bin, opts) when is_map(opts) do
    Wmbus.parse(bin, opts, [])
  end

  def parse_mbus(bin) do
    raise "TODO"
  end
end
