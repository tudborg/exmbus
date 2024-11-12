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
    # parse the APL
    &Exmbus.Parser.Apl.parse/1,
    # Expand compact frames
    &Exmbus.Parser.Apl.CompactFrame.maybe_expand/1
  ]

  defstruct [
    # configuration:
    opts: %{},
    # handlers to apply, in order:
    handlers: @default_handlers,
    current_handler: nil,
    # remaining binary data
    bin: nil,
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

  def new(attrs \\ []) do
    merge(%__MODULE__{}, attrs)
  end

  def merge(%__MODULE__{} = ctx, attrs \\ []) do
    Enum.reduce(attrs, ctx, &merge_key/2)
  end

  # errors are appended:
  defp merge_key({:errors, errors}, ctx),
    do: Map.update(ctx, :errors, [], &(&1 ++ errors))

  # optionsare Map.merge/2'ed:
  defp merge_key({:opts, opts}, ctx),
    do: %{ctx | opts: Map.merge(ctx.opts, Enum.into(opts || [], %{}))}

  # any other key is overwritten:
  defp merge_key({key, value}, ctx),
    do: %{ctx | key => value}

  @doc """
  Apply the context to the next handler in the list.
  """
  def handle(%__MODULE__{handlers: []} = ctx) do
    {:abort, ctx}
  end

  def handle(%__MODULE__{handlers: [handler | handlers]} = ctx) do
    case handler.(%{ctx | handlers: handlers, current_handler: handler}) do
      {:continue, ctx} -> {:continue, ctx}
      {:abort, ctx} -> {:abort, ctx}
    end
  end

  @doc """
  Add an error to the context and return the updated context.
  """
  def add_error(ctx, error) do
    %__MODULE__{ctx | errors: [{ctx.current_handler, error} | ctx.errors]}
  end

  @doc """
  Add a warning to the context and return the updated context.
  """
  def add_warning(ctx, warning) do
    %__MODULE__{ctx | warnings: [{ctx.current_handler, warning} | ctx.warnings]}
  end

  @doc """
  Check if there are any errors in the context.
  """
  @spec has_errors?(t) :: boolean
  def has_errors?(%__MODULE__{errors: []}), do: false
  def has_errors?(%__MODULE__{errors: [_ | _]}), do: true
end
