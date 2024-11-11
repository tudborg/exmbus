defmodule Exmbus do
  @moduledoc """
  Documentation for `Exmbus`.
  """
  alias Exmbus.Parser.Context
  alias Exmbus.Parser.ParseError

  @spec parse(binary, opts :: Keyword.t(), ctx :: Context.t()) ::
          {:ok, Context.t(), binary} | {:error, Context.t()}
  def parse(bin, opts \\ nil, ctx \\ nil) do
    case Exmbus.Parser.parse(bin, opts, ctx) do
      {:ok, context, rest} -> {:ok, context, rest}
      {:error, context} -> {:error, context}
    end
  end

  def parse!(bin, opts \\ nil, ctx \\ nil) do
    case parse(bin, opts, ctx) do
      {:ok, %Context{errors: []} = ctx, <<>>} ->
        ctx

      {:ok, %Context{errors: errors}, <<>>} ->
        raise ParseError, message: "Failed to parse: #{inspect(errors)}", errors: errors

      {:ok, ctx, rest} ->
        raise ParseError,
          message: "Failed to parse the entire binary. #{byte_size(rest)} bytes left",
          errors: ctx.errors ++ [{:failed_to_parse_entire_binary, rest}]

      {:error, %Context{errors: errors}} when is_list(errors) ->
        raise ParseError, message: "Failed to parse: #{inspect(errors)}", errors: errors
    end
  end

  @doc """
  Calculate the CRC relevant for mbus (crc_16_en_13757)
  """
  def crc!(bytes) when is_binary(bytes) do
    CRC.crc(:crc_16_en_13757, bytes)
  end
end
