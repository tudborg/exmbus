defmodule Exmbus.Key do
  @moduledoc """
  This module provides a way to define and retrieve keys for the Exmbus parser.
  """

  alias Exmbus.Parser.Context
  defstruct keyfn: nil

  @type t :: %__MODULE__{
          keyfn: (Context.t() -> {:ok, [binary()]} | {:error, any()})
        }

  def by_fn!(fun) when is_function(fun, 1) do
    %__MODULE__{keyfn: fun}
  end

  @doc """
  Given a Key struct, will invoke key function with options and context,
  and return a list of keys from the key function, or an error as appropriate.

    iex> key = Key.by_fn!(fn(_ctx) -> {:ok, [<<1>>, <<2>>]} end)
    iex> {:ok, [<<1>>, <<2>>]} = Key.get(key, Exmbus.Parser.Context.new())
  """
  @spec get(t(), ctx :: Context.t()) ::
          {:ok, [binary()]} | {:error, reason :: any()}
  def get(%__MODULE__{keyfn: keyfn}, ctx) do
    case keyfn.(ctx) do
      {:ok, keys} when is_list(keys) -> {:ok, keys}
      {:error, reason} -> {:error, {:keyfn_error, reason}}
    end
  end

  @doc """
  Short-hand for getting the key struct out of the option key :key
  and calling key on that.

  See get/3
  """
  def get(ctx) do
    with {:ok, key} <- from_options(ctx.opts) do
      get(key, ctx)
    end
  end

  def from_options(%{key: %__MODULE__{} = key}) do
    {:ok, key}
  end

  def from_options(%{key: fun}) when is_function(fun, 1) do
    {:ok, by_fn!(fun)}
  end

  def from_options(%{key: key_bytes}) when is_binary(key_bytes) do
    {:ok, by_fn!(fn _ctx -> {:ok, [key_bytes]} end)}
  end

  def from_options(%{key: list_of_key_bytes})
      when is_list(list_of_key_bytes) and is_binary(hd(list_of_key_bytes)) do
    {:ok, by_fn!(fn _ctx -> {:ok, list_of_key_bytes} end)}
  end

  def from_options(%{key: []}) do
    {:ok, by_fn!(fn _ctx -> {:ok, []} end)}
  end

  def from_options(%{} = opts) when not is_map_key(opts, :key) do
    {:error, {:no_key_in_options, opts}}
  end

  def from_options!(opts) do
    case from_options(opts) do
      {:ok, key} -> key
      {:error, reason} -> raise "could not retrieve key from options: #{inspect(reason)}"
    end
  end
end
