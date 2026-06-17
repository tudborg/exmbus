defmodule Exmbus.Util do
  @moduledoc """
  Utilities for manipulating data using the Exmbus library.
  """
  alias Exmbus.Parser.Context

  @doc """
  Re-key the ELL payload, returning the original headers with the rekeyed payload.
  """
  def rekey_ell(frame, input_opts, output_opts)
      when is_binary(frame) and is_list(input_opts) and is_list(output_opts) do
    # parse up to and including the ELL headers
    handlers = [
      # parse the DLL
      &Exmbus.Parser.Dll.parse/1,
      # parse the ELL
      &Exmbus.Parser.Ell.parse/1
    ]

    ctx = Context.new(handlers: handlers, opts: input_opts)
    {:ok, ctx} = Exmbus.parse(frame, ctx)
    {:next, ctx} = Exmbus.Parser.Ell.decrypt_bin(ctx)

    # now we need to reverse the flow, let's get the output options in
    ctx = Context.merge_opts(ctx, output_opts)

    # if ctx opts has identification_no, swap it out in the dll context before unparsing
    ctx =
      case ctx.opts[:identification_no] do
        nil -> ctx
        id -> put_in(ctx.dll.identification_no, id)
      end

    {:next, ctx} = Exmbus.Parser.Ell.encrypt_bin(ctx)
    {:next, ctx} = Exmbus.Parser.Ell.unparse(ctx)
    {:next, ctx} = Exmbus.Parser.Dll.unparse(ctx)
    {:ok, ctx.bin}
  end

  @doc """
  Extract the APL bytes (after decryption) from the frame.
  """
  def extract_apl_bytes(frame, opts) when is_binary(frame) do
    handlers =
      Enum.take_while(Context.default_handlers(), fn handler ->
        handler != (&Exmbus.Parser.Apl.parse/1)
      end)

    ctx = Context.new(handlers: handlers, opts: opts)

    case Exmbus.parse(frame, ctx) do
      {:ok, %{errors: [], warnings: []} = ctx} ->
        # if the frame parsed successfully with no errors and no warnings
        # the ctx.bin is the remaining bytes, which should be the APL bytes.
        {:ok, ctx.bin}

      {:error, %Context{} = ctx} ->
        {:error, ctx}

      {:ok, %Context{} = ctx} ->
        {:error, ctx}
    end
  end
end
