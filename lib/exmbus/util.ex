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
    {:continue, ctx} = Exmbus.Parser.Ell.decrypt_bin(Context.merge(ctx, opts: [key: old_key]))
    {:continue, ctx} = Exmbus.Parser.Ell.encrypt_bin(Context.merge(ctx, opts: [key: new_key]))
    reencrypted = ctx.bin
    # now we graft the reencrypted payload onto the original headers
    {:ok, :binary.part(frame, 0, byte_size(frame) - byte_size(encrypted)) <> reencrypted}
  end
end
