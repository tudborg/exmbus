defmodule Parser.Ell.DecryptEncryptTest do
  @moduledoc """
  tests decrypting and re-encrypting an ELL payload.

  Also tests frame parsing after re-encryption in general,
  so this test will also fail if some other parts of the parser are broken.
  """

  use ExUnit.Case, async: true
  alias Exmbus.Parser.Ell
  alias Exmbus.Parser.Context

  @frame [
           # DLL,
           "442D2C113134273302",
           # ELL headers,
           "8D20E9603A1020",
           # encrypted ELL payload
           "08C67C819AAE99B4DE753AA136EF64917ED9D8B2E2D35840BDEA173B8FE14CCE3F1406B7CF"
         ]
         |> Enum.join()
         |> Base.decode16!()

  @key "0102030405060708090A0B0C0D0E0F10" |> Base.decode16!()
  @rekey "FFFEFDFCFBFAF9F8F7F6F5F4F3F2F1F0" |> Base.decode16!()

  test "decrypt and encrypt" do
    # parse up to and incuding the ELL headers
    handlers = [
      # parse the DLL
      &Exmbus.Parser.Dll.parse/1,
      # parse the ELL
      &Exmbus.Parser.Ell.maybe_parse/1
    ]

    ctx = Context.new(handlers: handlers, opts: [length: false, key: [@rekey, @key]])
    assert {:ok, ctx} = Exmbus.parse(@frame, ctx)

    # grab the encrypted bin:
    encrypted = ctx.bin
    # decrypt it:
    {:continue, ctx} = Ell.decrypt_bin(ctx)
    decrypted = ctx.bin
    # re-encrypt it:
    {:continue, ctx} = Ell.encrypt_bin(ctx)
    # grab the re-encrypted bin:
    reencrypted = ctx.bin
    # attempt to decrypt again:
    {:continue, rectx} = Ell.decrypt_bin(ctx)
    redecrypted = rectx.bin

    # rekeying should change the decrypted payload
    assert encrypted != reencrypted
    # the resulting decrypted data should still match though
    assert decrypted == redecrypted

    # check that the frame still parses when applying the remaining handlers
    # to the re-encrypted data
    remaining_handlers = Context.default_handlers() -- handlers
    ctx = Context.merge(ctx, handlers: remaining_handlers)
    assert {:ok, _ctx} = Exmbus.parse(reencrypted, ctx)
  end
end
