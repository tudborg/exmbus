defmodule Exmbus.Parser.Apl.DataRecord.Header do
  alias Exmbus.Parser.Apl.DataRecord.DataInformationBlock, as: DIB
  alias Exmbus.Parser.Apl.DataRecord.ValueInformationBlock, as: VIB

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
    defstruct dib: nil,
              vib: nil,
              # human friendly reason why this header was invalid
              error_message: nil
  end

  @doc """
  Parses the next DataRecord Header from a binary.
  """
  def parse(bin, opts \\ [], ctx \\ []) do
    {:ok, dib_bytes, rest_after_dib} = collect_block(bin)

    case DIB.parse(dib_bytes, opts, ctx) do
      {:special_function, type, <<>>} ->
        # we just return the special function. The parser upstream will have to decide what to do,
        # but there isn't a real header here. The APL layer knows what to do.
        {:special_function, type, rest_after_dib}

      {:ok, [%DIB{} = dib | _] = inner_ctx, <<>>} ->
        {:ok, vib_bytes, rest_after_vib} = collect_block(rest_after_dib)
        # We found a DataInformationBlock.
        # We now expect a VIB to follow, which needs the context from the DIB to be able to parse
        # correctly.
        case VIB.parse(vib_bytes, opts, inner_ctx) do
          {:ok, [%VIB{} = vib, %DIB{} = dib | _], <<>>} ->
            {:ok, coding} = summarize_coding(dib, vib)

            {
              :ok,
              # Wrap the VIB and DIB into a DataRecord.Header
              [
                %__MODULE__{
                  dib_bytes: dib_bytes,
                  vib_bytes: vib_bytes,
                  dib: dib,
                  vib: vib,
                  coding: coding
                }
                | ctx
              ],
              rest_after_vib
            }

          {:error, {:invalid, reason}, <<>>} ->
            {:ok,
             [
               %InvalidHeader{
                 dib: dib,
                 vib: nil,
                 error_message: "VIB invalid with reason #{inspect(reason)}"
               }
               | ctx
             ], rest_after_vib}
        end

      {:error, reason, <<>>} ->
        {:ok, [%InvalidHeader{error_message: "Parsing DIB failed: #{inspect(reason)}"} | ctx],
         rest_after_dib}
    end
  end

  def unparse(opts, [%__MODULE__{vib: vib, dib: dib} | ctx]) do
    with {:ok, vib_bytes, ctx} <- VIB.unparse(opts, [vib, dib | ctx]),
         {:ok, dib_bytes, ctx} <- DIB.unparse(opts, ctx) do
      {:ok, <<dib_bytes::binary, vib_bytes::binary>>, ctx}
    end
  end

  @doc """
  Collect a byte block.
  A block is a sequence of bytes where the first bit in each byte
  represents if the next byte is part of the block.

    iex> {:ok, <<0xFF, 0x00>>, <<0x00>>} = collect_block(<<0xFF, 0x00, 0x00>>)

    iex> {:ok, <<0x00>>, <<0x00>>} = collect_block(<<0x00, 0x00>>)

    iex> {:ok, <<0x80, 0x80, 0x00>>, <<0x00>>} = collect_block(<<1::1, 0::7, 1::1, 0::7, 0x00, 0x00>>)

  """
  def collect_block(bin) do
    collect_block(0, bin)
  end

  defp collect_block(byte_len, bin) do
    byte_len_with_next = byte_len + 1

    case bin do
      <<_::binary-size(byte_len), 0::1, _::7, _::binary>> ->
        <<block::binary-size(byte_len_with_next), rest::binary>> = bin
        {:ok, block, rest}

      <<_::binary-size(byte_len), 1::1, _::7, _::binary>> ->
        collect_block(byte_len_with_next, bin)
    end
  end

  defp summarize_coding(dib, %VIB{coding: nil}) do
    {:ok, DIB.default_coding(dib)}
  end

  defp summarize_coding(_dib, %VIB{coding: coding}) do
    {:ok, coding}
  end
end
