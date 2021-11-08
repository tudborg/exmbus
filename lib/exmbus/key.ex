defmodule Exmbus.Key do
  
  defstruct [
    keyfn: nil
  ]

  def by_fn(fun) do
    %__MODULE__{keyfn: fun}
  end

  def keys_for_parse_stack(%__MODULE__{keyfn: fun}, opts, parse_stack) do
    case fun.(opts, parse_stack) do
      {:ok, keys} when is_list(keys) -> {:ok, keys}
    end
  end
end
