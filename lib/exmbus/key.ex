defmodule Exmbus.Key do

  defstruct [
    keyfn: nil
  ]

  def by_fn(fun) do
    %__MODULE__{keyfn: fun}
  end

  @doc """
  Given a Key struct, get the keys, handing the key struct the options and current context.
  Returns a list of keys
  """
  @spec get(%Exmbus.Key{}, options :: map(), ctx :: list()) :: {:ok, [binary()]} | {:error, reason :: any(), ctx :: list()}
  def get(%__MODULE__{keyfn: keyfn}, opts, ctx) do
    case keyfn.(opts, ctx) do
      {:ok, keys} when is_list(keys) -> {:ok, keys}
      {:error, reason} -> {:error, reason, ctx}
      {:error, _e, error_ctx}=e when is_list(error_ctx) -> e
    end
  end

  @doc """
  Short-hand for getting the key struct out of the option key :key
  and calling key on that.

  See get/3
  """
  def get(%{}=opts, ctx) do
    with key <- from_options!(opts) do
      get(key, opts, ctx)
    end
  end

  def from_options!(%{key: %__MODULE__{}=key}) do
    key
  end
  def from_options!(%{key: key_bytes}) when is_binary(key_bytes) do
    %__MODULE__{keyfn: fn(_,_) -> {:ok, [key_bytes]} end}
  end
  def from_options!(%{key: list_of_key_bytes}) when is_list(list_of_key_bytes) and is_binary(hd(list_of_key_bytes)) do
    %__MODULE__{keyfn: fn(_,_) -> {:ok, list_of_key_bytes} end}
  end
  def from_options!(%{}=opts) do
    raise "the map key :key not found in options: #{inspect opts}"
  end

end
