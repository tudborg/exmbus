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
    %__MODULE__{}
    |> append_handlers(default_handlers())
    |> merge(attrs)
  end

  @doc """
  Merge the given attributes into the context.

  The attributes are merged in the following way:
  - `:errors` - appended to the existing list of errors
  - `:warnings` - appended to the existing list of warnings
  - `:opts` - merged with the existing opts
  - any other key - overwritten
  """
  def merge(%__MODULE__{} = ctx, attrs \\ []) do
    Enum.reduce(attrs, ctx, &merge_key/2)
  end

  # errors are appended:
  defp merge_key({:errors, errors}, ctx),
    do: Map.update(ctx, :errors, [], &(&1 ++ errors))

  # warnings are appended:
  defp merge_key({:warnings, warnings}, ctx),
    do: Map.update(ctx, :warnings, [], &(&1 ++ warnings))

  # optionsare Map.merge/2'ed:
  defp merge_key({:opts, opts}, ctx),
    do: %{ctx | opts: Map.merge(ctx.opts, Enum.into(opts || [], %{}))}

  # any other key is overwritten:
  defp merge_key({key, value}, ctx),
    do: %{ctx | key => value}

  @doc """
  Append additional handlers to the context.
  """
  def append_handlers(%__MODULE__{} = ctx, handlers) do
    %__MODULE__{ctx | handlers: (ctx.handlers || []) ++ handlers}
  end

  @doc """
  Apply the context to the next handler in the list.
  """
  def handle(%__MODULE__{handlers: []} = ctx) do
    {:abort, ctx}
  end

  def handle(%__MODULE__{handlers: [handler | handlers]} = ctx) do
    case handler.(%{ctx | handlers: handlers, handler: handler}) do
      {:continue, ctx} -> {:continue, ctx}
      {:abort, ctx} -> {:abort, ctx}
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
