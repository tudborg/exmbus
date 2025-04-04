defmodule Exmbus do
  @moduledoc """
  Documentation for `Exmbus`.
  """
  alias Exmbus.Parser.Context
  alias Exmbus.Parser.ParseError

  @spec parse(binary, options_or_context :: Keyword.t() | Context.t() | nil) ::
          {:ok, Context.t()} | {:error, Context.t()}
  def parse(bin, options_or_context \\ nil) do
    # normalize input to a Context struct
    case options_or_context do
      %Context{} = ctx -> %{ctx | bin: bin}
      opts when is_map(opts) -> Context.new(opts: opts, bin: bin)
      opts when is_list(opts) -> Context.new(opts: opts, bin: bin)
      nil -> Context.new(bin: bin)
    end
    # send down the parser
    |> Exmbus.Parser.parse()
  end

  def parse!(bin, options_or_context \\ nil) do
    case parse(bin, options_or_context) do
      {:ok, ctx} -> ctx
      {:error, ctx} -> raise ParseError, message: "Failed to parse data", errors: ctx.errors
    end
  end

  @doc """
  Calculate the CRC relevant for mbus (crc_16_en_13757)
  """
  @spec crc!(iodata()) :: non_neg_integer()
  def crc!(bytes) do
    CRC.crc(:crc_16_en_13757, bytes)
  end
end
