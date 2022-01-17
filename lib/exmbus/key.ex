defmodule Exmbus.Key do

  defstruct [
    keyfn: nil
  ]

  def by_fn!(fun) when is_function(fun, 2) do
    %__MODULE__{keyfn: fun}
  end

  @doc """
  Given a Key struct, will invoke key function with options and context,
  and return a list of keys from the key function, or an error as appropriate.

    iex> key = Key.by_fn!(fn(_opts, _ctx) -> {:ok, [<<1>>, <<2>>]} end)
    iex> {:ok, [<<1>>, <<2>>]} = Key.get(key, %{}, [])
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
  def from_options!(%{key: []}) do
    %__MODULE__{keyfn: fn(_,_) -> {:ok, []} end}
  end
  def from_options!(%{}=opts) when not is_map_key(opts, :key) do
    raise "the map key :key not found in options: #{inspect opts}"
  end

end
