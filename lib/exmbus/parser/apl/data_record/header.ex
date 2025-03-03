defmodule Exmbus.Parser.Apl.DataRecord.Header do
  @moduledoc """
  This module represents the header of a DataRecord.
  """
  alias Exmbus.Parser.Apl.DataRecord.DataInformationBlock, as: DIB
  alias Exmbus.Parser.Apl.DataRecord.ValueInformationBlock, as: VIB

  @type t :: %__MODULE__{
          dib_bytes: binary(),
          vib_bytes: binary(),
          dib: DIB.t(),
          vib: VIB.t(),
          coding: atom()
        }

  # The header struct
  defstruct dib_bytes: nil,
            vib_bytes: nil,
            # A %DataInformationBlock{}
            dib: nil,
            # A %ValueInformationBlock{}
            vib: nil,
            # The summarized coding to use for this header
            coding: nil

  defmodule InvalidHeader do
    @moduledoc """
    This module represents an invalid header.
    """
    defstruct dib: nil,
              vib: nil,
              # human friendly reason why this header was invalid
              error_message: nil
  end

  @doc """
  Parses the next DataRecord Header from a binary.
  """
  def parse(bin, ctx) do
    case DIB.parse(bin, ctx) do
      {:special_function, type, rest_after_dib} ->
        # we just return the special function. The parser upstream will have to decide what to do,
        # but there isn't a real header here. The APL layer knows what to do.
        {:special_function, type, rest_after_dib}

      {:ok, %DIB{} = dib, rest_after_dib} ->
        # We found a DataInformationBlock.
        # We now expect a VIB to follow, which needs the context from the DIB to be able to parse
        # correctly.
        case VIB.parse(rest_after_dib, %{ctx | dib: dib}) do
          {:ok, %VIB{} = vib, rest_after_vib} ->
            dib_size = byte_size(bin) - byte_size(rest_after_dib)
            vib_size = byte_size(rest_after_dib) - byte_size(rest_after_vib)

            <<
              dib_bytes::binary-size(dib_size),
              vib_bytes::binary-size(vib_size),
              _::binary
            >> = bin

            {:ok, coding} = summarize_coding(dib, vib)

            {
              :ok,
              # Wrap the VIB and DIB into a DataRecord.Header
              %__MODULE__{
                dib_bytes: dib_bytes,
                vib_bytes: vib_bytes,
                dib: dib,
                vib: vib,
                coding: coding
              },
              rest_after_vib
            }

          {:error, {:invalid, reason}, rest_after_vib} ->
            {:ok,
             %InvalidHeader{
               dib: dib,
               vib: nil,
               error_message: "VIB invalid with reason #{inspect(reason)}"
             }, rest_after_vib}
        end

      {:error, reason, rest_after_dib} ->
        {:ok, %InvalidHeader{error_message: "Parsing DIB failed: #{inspect(reason)}"},
         rest_after_dib}
    end
  end

  def unparse(%__MODULE__{vib: vib, dib: dib}) do
    with {:ok, vib_bytes} <- VIB.unparse(vib),
         {:ok, dib_bytes} <- DIB.unparse(dib) do
      {:ok, <<dib_bytes::binary, vib_bytes::binary>>}
    end
  end

  defp summarize_coding(dib, %VIB{coding: nil}) do
    {:ok, DIB.default_coding(dib)}
  end

  defp summarize_coding(_dib, %VIB{coding: coding}) do
    {:ok, coding}
  end
end
