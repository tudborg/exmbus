defmodule Exmbus.Parser.Context do
  @moduledoc """
  Parsing context, accumulating errors and layers.
  """

  @type t :: %__MODULE__{
          #
          opts: map(),
          #
          bin: binary | nil,
          #
          dll: any,
          tpl: any,
          ell: any,
          apl: any,
          #
          dib: any,
          vib: any,
          #
          errors: [any]
        }

  @default_handlers [
    # parse the DLL
    &Exmbus.Parser.Dll.parse/1,
    # parse the ELL
    &Exmbus.Parser.Ell.maybe_parse/1,
    # apply decryption from the ELL to remaining data
    &Exmbus.Parser.Ell.maybe_decrypt_bin/1,
    # parse the TPL
    &Exmbus.Parser.Tpl.parse/1,
    # apply decryption from the TPL to remaining data
    &Exmbus.Parser.Tpl.decrypt_bin/1,
    # parse the APL based on the frame type specified in the TPL
    &Exmbus.Parser.Apl.parse/1,
    # expand compact frames
    &Exmbus.Parser.Apl.CompactFrame.maybe_expand/1,
    # expand compact profiles
    &Exmbus.Parser.Apl.FullFrame.maybe_expand_compact_profiles/1
  ]

  defstruct [
    # remaining binary data
    bin: nil,
    # configuration:
    opts: %{},
    # handlers to apply, in order:
    handlers: nil,
    # current (most recent) handler being applied
    handler: nil,
    # lower layers:
    dll: nil,
    ell: nil,
    tpl: nil,
    apl: nil,
    # state for when parsing data record:
    # TODO: move to it's own ACC so it doesnt polute the state?
    # #reason for keeping it here is that it is useful
    # for debugging when parsing fails, but maybe
    # the errors should have more information?
    # otherwise, maybe have a generic "current parse state" field
    # that other layers can use?
    dib: nil,
    vib: nil,
    # error and warning accumulator
    errors: [],
    warnings: []
  ]

  @doc """
  Return the list of default handlers.
  """
  def default_handlers() do
    @default_handlers
  end

  @doc """
  Create a new context  with default handlers, and merge the given attributes into the context.
  """
  def new(attrs \\ []) do
    attrs
    |> Keyword.drop([:opts])
    |> Keyword.put_new_lazy(:handlers, &default_handlers/0)
    # |> Enum.reduce(attrs, %__MODULE__{}, &merge_key/2)
    |> __struct__()
    |> merge_opts(Keyword.get(attrs, :opts, %{}))
  end

  @doc """
  Merge options with the existing options in the context.
  """
  def merge_opts(ctx, opts) do
    %{ctx | opts: Map.merge(ctx.opts, Enum.into(opts || [], %{}))}
  end

  @doc """
  Append additional handlers to the context.
  """
  def append_handlers(%__MODULE__{} = ctx, handlers) when is_list(handlers) do
    %__MODULE__{ctx | handlers: (ctx.handlers || []) ++ handlers}
  end

  @doc """
  Prepend additional handlers to the context.

  Prepending handlers will make the given handlers run before the existing handlers.
  """
  def prepend_handlers(%__MODULE__{} = ctx, handlers) when is_list(handlers) do
    %__MODULE__{ctx | handlers: handlers ++ (ctx.handlers || [])}
  end

  @doc """
  Apply the context to the next handler in the list.
  """
  def handle(%__MODULE__{handlers: []} = ctx) do
    {:halt, ctx}
  end

  def handle(%__MODULE__{handlers: [handler | handlers]} = ctx) do
    case handler.(%{ctx | handlers: handlers, handler: handler}) do
      {:next, ctx} -> {:next, ctx}
      {:halt, ctx} -> {:halt, ctx}
    end
  end

  @doc """
  Add an error to the context and return the updated context.
  """
  def add_error(ctx, error) do
    %__MODULE__{ctx | errors: [{ctx.handler, error} | ctx.errors]}
  end

  @doc """
  Add a warning to the context and return the updated context.
  """
  def add_warning(ctx, warning) do
    %__MODULE__{ctx | warnings: [{ctx.handler, warning} | ctx.warnings]}
  end
end
