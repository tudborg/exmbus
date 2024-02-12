defmodule Exmbus do
  @moduledoc """
  Documentation for `Exmbus`.
  """
  alias Exmbus.Parser.Context
  alias Exmbus.Parser.ParseError

  def parse(bin, opts \\ nil, ctx \\ nil) do
    Exmbus.Parser.parse(bin, opts, ctx)
  end

  def parse!(bin, opts \\ nil, ctx \\ nil) do
    case parse(bin, opts, ctx) do
      {:ok, ctx, <<>>} ->
        ctx

      {:ok, ctx, rest} ->
        raise ParseError,
          message: "Failed to parse the entire binary. #{byte_size(rest)} bytes left",
          errors: ctx.errors ++ [{:failed_to_parse_entire_binary, rest}]

      {:error, %Context{errors: errors}} when is_list(errors) ->
        raise ParseError, message: "Failed to parse", errors: errors
    end
  end

  @doc """
  Calculate the CRC relevant for mbus (crc_16_en_13757)
  """
  def crc!(bytes) when is_binary(bytes) do
    CRC.crc(:crc_16_en_13757, bytes)
  end
end
