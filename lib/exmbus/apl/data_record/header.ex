
defmodule Exmbus.Apl.DataRecord.Header do
  alias Exmbus.Apl.DataRecord.DataInformationBlock, as: DIB
  alias Exmbus.Apl.DataRecord.ValueInformationBlock, as: VIB

  use Bitwise

  # The header struct
  defstruct [
    dib: nil, # A %DataInformationBlock{}
    vib: nil, # A %ValueInformationBlock{}
    coding: nil, # The summarized coding to use for this header
  ]

  @doc """
  Parses the next DataRecord Header from a binary.
  """
  def parse(bin, opts \\ [], ctx \\ []) do
    case DIB.parse(bin, opts, ctx) do
      {:special_function, _type, _rest}=s ->
        # we just return the special function. The parser upstream will have to decide what to do,
        # but there isn't a real header here. The APL layer knows what to do.
        s
      {:ok, [%DIB{} | _]=inner_ctx, rest} ->
        # We found a DataInformationBlock.
        # We now expect a VIB to follow, which needs the context from the DIB to be able to parse
        # correctly.
        case VIB.parse(rest, opts, inner_ctx) do
          {:ok, [%VIB{}=vib, %DIB{}=dib | _], rest} ->
            {:ok, coding} = summarize_coding(dib, vib)
            {:ok,
              # Wrap the VIB and DIB into a DataRecord.Header
              [%__MODULE__{
                dib: dib,
                vib: vib,
                coding: coding,
              } | ctx], rest}
        end
    end
  end

  defp summarize_coding(dib, %VIB{coding: nil}) do
    {:ok, DIB.default_coding(dib)}
  end
  defp summarize_coding(_dib, %VIB{coding: coding}) do
    {:ok, coding}
  end


end
