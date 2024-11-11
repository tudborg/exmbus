defmodule Exmbus.Parser.Apl.Unparsed do
  @moduledoc """
  Contains the raw APL and encryption mode.
  This struct is usually an intermedidate struct
  and will not show in the final parse stack unless options are given
  to not parse the APL.
  """
  alias Exmbus.Parser.Context
  alias Exmbus.Parser.Tpl

  defstruct encrypted_bytes: nil,
            plain_bytes: nil,
            mode: nil

  def parse(%{rest: bin, tpl: %Tpl{} = tpl} = ctx) do
    mode = Tpl.encryption_mode(tpl)
    {:ok, enclen} = Tpl.encrypted_byte_count(tpl)
    <<enc::binary-size(enclen), plain::binary>> = bin
    apl = %__MODULE__{mode: mode, encrypted_bytes: enc, plain_bytes: plain}
    {:continue, Context.merge(ctx, apl: apl, rest: <<>>)}
  end

  def parse(%{rest: bin} = ctx) do
    apl = %__MODULE__{mode: 0, encrypted_bytes: <<>>, plain_bytes: bin}
    {:continue, Context.merge(ctx, apl: apl, rest: <<>>)}
  end

  @doc """
  Given a context with an `apl` set to an `Apl.Unparsed`,
  return a context without an `apl` set, and the bytes from the `Apl.Unparsed` moved to the `rest` field
  such that parsing of the Apl records can continue.
  """
  @spec move_to_context(Context.t()) :: {:continue, Context.t()} | {:abort, Context.t()}
  def move_to_context(
        %{apl: %__MODULE__{mode: 0, plain_bytes: plain, encrypted_bytes: <<>>}} = ctx
      ) do
    {:continue, Context.merge(ctx, rest: plain, apl: nil)}
  end

  def move_to_context(
        %{apl: %__MODULE__{mode: mode, encrypted_bytes: enc, plain_bytes: plain}, tpl: tpl} = ctx
      ) do
    enclen = byte_size(enc)
    # assert that the %Unparsed{} information and the TPL information match
    ^mode = Tpl.encryption_mode(tpl)
    {:ok, ^enclen} = Tpl.encrypted_byte_count(tpl)
    {:continue, Context.merge(ctx, apl: nil, rest: <<enc::binary, plain::binary>>)}
  end
end
