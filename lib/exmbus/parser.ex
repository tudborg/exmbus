defmodule Exmbus.Parser do
  @moduledoc """
  Responsible for parsing the binary data into a structured format.
  """

  def parse!(bin, opts \\ %{}) do
    case parse(bin, opts) do
      {:ok, result, <<>>} ->
        result

      {:error, reason} ->
        raise "failed to parse. reason=#{inspect(reason)}"

      {:error, reason, ctx} ->
        raise "failed to parse. reason=#{inspect(reason)} ctx=#{inspect(ctx)}"
    end
  end

  def parse(bin, opts \\ %{}, ctx \\ [])

  def parse(bin, opts, ctx) when not is_map(opts) do
    parse(bin, Enum.into(opts, %{}), ctx)
  end

  def parse(bin, opts, ctx) when is_map(opts) and is_list(ctx) do
    Exmbus.Parser.Dll.parse(bin, opts, ctx)
  end
end
