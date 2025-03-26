defmodule Exmbus.Util do
  @moduledoc """
  Utilities for manipulating data using the Exmbus library.
  """
  alias Exmbus.Parser.Context

  @doc """
  Re-key the ELL payload, returning the original headers with the rekeyed payload.
  """
  def rekey_ell(frame, opts, old_key, new_key) when is_binary(frame) do
    # parse up to and incuding the ELL headers
    handlers = [
      # parse the DLL
      &Exmbus.Parser.Dll.parse/1,
      # parse the ELL
      &Exmbus.Parser.Ell.parse/1
    ]

    ctx = Context.new(handlers: handlers, opts: opts)
    {:ok, ctx} = Exmbus.parse(frame, ctx)
    encrypted = ctx.bin
    {:next, ctx} = Exmbus.Parser.Ell.decrypt_bin(Context.merge_opts(ctx, key: old_key))
    {:next, ctx} = Exmbus.Parser.Ell.encrypt_bin(Context.merge_opts(ctx, key: new_key))
    reencrypted = ctx.bin
    # now we graft the reencrypted payload onto the original headers
    {:ok, :binary.part(frame, 0, byte_size(frame) - byte_size(encrypted)) <> reencrypted}
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

    with {:ok, %{errors: [], warnings: []} = ctx} <- Exmbus.parse(frame, ctx) do
      # if the frame parsed successfully with no errors and no warnings
      # the ctx.bin is the remaining bytes, which should be the APL bytes.
      {:ok, ctx.bin}
    else
      {:error, %Context{} = ctx} -> {:error, ctx}
      {:ok, %Context{} = ctx} -> {:error, ctx}
    end
  end
end
