defmodule Exmbus do
  @moduledoc """
  Documentation for `Exmbus`.
  """
  alias Exmbus.Parser.Context
  alias Exmbus.Parser.ParseError

  @spec parse(binary, options_or_context :: Keyword.t() | Context.t()) ::
          {:ok, Context.t()} | {:error, Context.t()}
  def parse(bin, options_or_context \\ nil) do
    # normalize input to a Context struct
    case options_or_context do
      %Context{} = ctx -> Context.merge(ctx, bin: bin)
      opts when is_map(opts) -> Context.new(opts: opts, bin: bin)
      opts when is_list(opts) -> Context.new(opts: opts, bin: bin)
      nil -> Context.new(bin: bin)
    end
    # send down the parser
    |> Exmbus.Parser.parse()
    # rewrap maps the internal returns of the ParseBehaviour to {:ok, ctx} or {:error, ctx}
    |> rewrap()
  end

  def parse!(bin, options_or_context \\ nil) do
    case parse(bin, options_or_context) do
      {:ok, ctx} -> ctx
      {:error, ctx} -> raise ParseError, message: "Failed to parse data", errors: ctx.errors
    end
  end

  defp rewrap({:continue, ctx}) do
    {:ok, ctx}
  end

  defp rewrap({:abort, ctx}) do
    case Context.has_errors?(ctx) do
      true -> {:error, ctx}
      false -> {:ok, ctx}
    end
  end

  @doc """
  Calculate the CRC relevant for mbus (crc_16_en_13757)
  """
  def crc!(bytes) when is_binary(bytes) do
    CRC.crc(:crc_16_en_13757, bytes)
  end
end
