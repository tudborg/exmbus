defmodule Exmbus.Key do
  
  defstruct [
    keyfn: nil
  ]

  def by_fn(fun) do
    %__MODULE__{keyfn: fun}
  end

  def from_options(%{key: %__MODULE__{}=key}=opts, ctx) do
    keys_for_ctx(key, opts, ctx)
  end
  # no key given, return empty result
  def from_options(%{}=_opts, _ctx) do
    {:ok, []}
  end

  defp keys_for_ctx(%__MODULE__{keyfn: fun}, opts, ctx) do
    case fun.(opts, ctx) do
      {:ok, keys} when is_list(keys) -> {:ok, keys}
    end
  end

end
