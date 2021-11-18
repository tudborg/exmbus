defmodule Exmbus.Apl do

  alias Exmbus.Apl
  alias Exmbus.Apl.DataRecord
  alias Exmbus.Tpl
  alias Exmbus.Key
  alias Exmbus.Dll.Wmbus
  alias Exmbus.Manufacturer
  alias Exmbus.Tpl.Device
  alias Exmbus.DataType
  alias Exmbus.Apl.FullFrame
  alias Exmbus.Apl.FormatFrame
  alias Exmbus.Apl.CompactFrame

  defmodule Raw do
    @moduledoc """
    Contains the raw APL and encryption mode.
    This struct is usually an intermedidate struct
    and will not show in the final parse stack unless options are given
    to not parse the APL.
    """
    defstruct [
      encrypted_bytes: nil,
      plain_bytes: nil,
      mode: nil,
    ]
  end

  @doc """
  Decode the Application Layer and return one of the Apl frame structs.

  The Application Layer consists of N number of records where N >= 0,
  and some optional manufacturer specific data.

  The function assumes that the entire input is the APL layer data.
  """
  def parse(bin, opts, ctx) do
    {:ok, ctx} = append_raw(bin, opts, ctx)
    parse_apl(opts, ctx)
  end

  def to_map!(%FullFrame{records: records, manufacturer_bytes: <<>>}) do
    %{records: Enum.map(records, &DataRecord.to_map!/1)}
  end

  defp parse_apl(opts, [%Raw{mode: 0, plain_bytes: bin} | ctx]) do
    parse_records(bin, opts, ctx)
  end
  # when encryption mode is 5 and key option is set:
  defp parse_apl(%{key: _}=opts, [%Raw{mode: 5, encrypted_bytes: enc, plain_bytes: plain} | ctx]) do
    with {:ok, decrypted} <- decrypt_mode_5(enc, opts, ctx) do
      parse_records(<<decrypted::binary, plain::binary>>, opts, ctx)
    end
  end
  # when no key is supplied or we don't understand how to decrypt, return parse context
  defp parse_apl(%{}, [%Raw{} | _]=ctx) do
    {:ok, ctx, <<>>}
  end



  # assume decrypted apl bytes as first argument, parse data fields
  # an return an {:ok, [Apl|ctx]}
  defp parse_records(bin, opts, [%Tpl{frame_type: :full_frame} | _]=ctx) do
    parse_full_frame(bin, opts, ctx)
  end
  defp parse_records(bin, opts, [%Tpl{frame_type: :format_frame} | _]=ctx) do
    parse_format_frame(bin, opts, ctx)
  end
  defp parse_records(bin, opts, [%Tpl{frame_type: :compact_frame} | _]=ctx) do
    parse_compact_frame(bin, opts, ctx)
  end

  #
  # Parse full-frame records:
  #
  defp parse_full_frame(<<>>, opts, ctx) do
    finalize_full_frame(<<>>, opts, ctx)
  end
  defp parse_full_frame(bin, opts, ctx) do
    case DataRecord.parse(bin, opts, ctx) do
      {:ok, [%DataRecord{} | _]=ctx, rest} ->
        parse_full_frame(rest, opts, ctx)
      # just skip the idle filler
      {:special_function, :idle_filler, rest} ->
        parse_full_frame(rest, opts, ctx)
      # manufacturer specific data is the rest of the APL data
      {:special_function, {:manufacturer_specific, :to_end}, rest} ->
        finalize_full_frame(rest, opts, ctx)
      {:special_function, {:manufacturer_specific, :more_records_follow}, rest} ->
        finalize_full_frame(rest, opts, ctx)
    end
  end

  defp finalize_full_frame(rest, _opts, ctx) do
    {rev_records, ctx} =
      ctx
      |> Enum.split_while(fn
        %DataRecord{} -> true
        _ -> false
      end)
    {:ok, [
      %FullFrame{
        records: Enum.reverse(rev_records),
        manufacturer_bytes: rest,
      } | ctx], <<>>}
  end

  #
  # Format Frame
  #

  defp parse_format_frame(<<len, format_signature::little-size(16), rest::binary>>, opts, ctx) do
    _parse_format_frame({len, format_signature}, rest, opts, ctx)
  end

  defp _parse_format_frame(ff_header, <<>>, opts, ctx) do
    finalize_format_frame(ff_header, <<>>, opts, ctx)
  end
  defp _parse_format_frame(ff_header, bin, opts, ctx) do
    case DataRecord.Header.parse(bin, opts, ctx) do
      {:ok, ctx, rest} ->
        _parse_format_frame(ff_header, rest, opts, ctx)
      # just skip the idle filler
      {:special_function, :idle_filler, rest} ->
        _parse_format_frame(ff_header, rest, opts, ctx)
      # manufacturer specific data is the rest of the APL data
      {:special_function, {:manufacturer_specific, :to_end}, rest} ->
        finalize_format_frame(ff_header, rest, opts, ctx)
      {:special_function, {:manufacturer_specific, :more_records_follow}, rest} ->
        finalize_format_frame(ff_header, rest, opts, ctx)
    end
  end

  defp finalize_format_frame({_len, format_signature}, <<>>, _opts, ctx) do
    {rev_headers, ctx} =
      ctx
      |> Enum.split_while(fn
        %DataRecord.Header{} -> true
        _ -> false
      end)

    full_frame = %FormatFrame{
      headers: Enum.reverse(rev_headers)
    }

    {:ok, ^format_signature} = FormatFrame.format_signature(full_frame)

    {:ok, [full_frame | ctx], <<>>}
  end
  #
  # Compact Frame
  #
  defp parse_compact_frame(bin, opts, ctx) do
    CompactFrame.parse(bin, opts, ctx)
  end


  # decrypt mode 5 bytes
  defp decrypt_mode_5(enc, opts, ctx) do
    {:ok, iv} = ctx_to_mode_5_iv(ctx)
    {:ok, byte_keys} = Key.from_options(opts, ctx)

    answer =
      Enum.find_value(byte_keys, fn
        (byte_key) when byte_size(byte_key) == 16 ->
          case :crypto.block_decrypt(:aes_cbc, byte_key, iv, enc) do
            <<0x2f, 0x2f, rest::binary>> -> {:ok, rest}
            _ -> nil # not the valid key
          end
        (byte_key) ->
          {:error, {:invalid_key, {:not_16_bytes, byte_key}}, ctx}
      end)

    case answer do
      {:ok, bin}=ok -> ok
      {:error, _reason, _ctx}=e -> e
      nil -> {:error, {:mode_5_decryption_failed, byte_keys}, ctx}
    end
  end


  # append a Raw struct to the parse stack
  defp append_raw(bin, _opts, [%Tpl{}=tpl | _]=ctx) do
    {:mode, m} = Tpl.encryption_mode(tpl)
    {:ok, enclen} = Tpl.encrypted_byte_count(tpl)
    <<enc::binary-size(enclen), plain::binary>> = bin
    {:ok,
      [%Raw{
        mode: m,
        encrypted_bytes: enc,
        plain_bytes: plain,
      } | ctx]}
  end

  # Generate the IV for mode 5 encryption
  defp ctx_to_mode_5_iv([%Tpl{header: %Tpl.Short{access_no: a_no}}, %Wmbus{}=wmbus | _]) do
    %Wmbus{manufacturer: m, identification_no: i, version: v, device: d} = wmbus
    {:ok, man_bytes} = Manufacturer.encode(m)
    {:ok, id_bytes} = DataType.encode_type_a(i, 32)
    device_byte = Device.encode(d)
    {:ok, <<man_bytes::binary, id_bytes::binary, v, device_byte::binary,
            a_no, a_no, a_no, a_no, a_no, a_no, a_no, a_no>>}
  end
  defp ctx_to_mode_5_iv([%Tpl{header: %Tpl.Long{}=header} | _]) do
    %Tpl.Long{manufacturer: m, identification_no: id, version: v, device: d, access_no: a_no} = header
    {:ok, man_bytes} = Manufacturer.encode(m)
    {:ok, id_bytes} = DataType.encode_type_a(id, 32)
    device_byte = Device.encode(d)
    {:ok, <<man_bytes::binary, id_bytes::binary, v, device_byte::binary,
            a_no, a_no, a_no, a_no, a_no, a_no, a_no, a_no>>}
  end

end
