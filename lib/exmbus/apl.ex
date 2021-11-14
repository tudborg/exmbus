defmodule Exmbus.Apl do

  alias Exmbus.Apl
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
    %{records: Enum.map(records, &Apl.DataRecord.to_map!/1)}
  end

  defp parse_apl(opts, [%Raw{mode: 0, plain_bytes: bin} | ctx]) do
    parse_records(bin, opts, ctx)
  end
  # when encryption mode is 5 and key option is set:
  defp parse_apl(%{key: %Key{}}=opts, [%Raw{mode: 5, encrypted_bytes: enc, plain_bytes: plain} | ctx]) do
    case decrypt_mode_5(enc, opts, ctx) do
      {:ok, decrypted} ->
        parse_records(<<decrypted::binary, plain::binary>>, opts, ctx)
    end
  end
  # when no key is supplied or we don't understand how to decrypt, return parse context
  defp parse_apl(%{}, [%Raw{} | _]=ctx) do
    {:ok, ctx}
  end



  # assume decrypted apl bytes as first argument, parse data fields
  # an return an {:ok, [Apl|ctx]}
  defp parse_records(bin, opts, [ %Tpl{frame_type: :full_frame} | _]=ctx) do
    parse_full_frame(bin, opts, ctx, [])
  end
  defp parse_records(bin, opts, [ %Tpl{frame_type: :format_frame} | _]=ctx) do
    parse_format_frame(bin, opts, ctx, [])
  end
  defp parse_records(bin, opts, [ %Tpl{frame_type: :compact_frame} | _]=ctx) do
    parse_compact_frame(bin, opts, ctx, [])
  end

  #
  # Parse full-frame records:
  #
  defp parse_full_frame(<<>>, opts, ctx, acc) do
    finalize_full_frame(<<>>, opts, ctx, acc)
  end
  defp parse_full_frame(bin, opts, ctx, acc) do
    case Apl.DataRecord.parse(bin, opts, ctx) do
      {:ok, [record | _], rest} ->
        parse_full_frame(rest, opts, ctx, [record | acc])
      # just skip the idle filler
      {:special_function, :idle_filler, rest} ->
        parse_full_frame(rest, opts, ctx, acc)
      # manufacturer specific data is the rest of the APL data
      {:special_function, {:manufacturer_specific, :to_end}, rest} ->
        finalize_full_frame(rest, opts, ctx, acc)
      {:special_function, {:manufacturer_specific, :more_records_follow}, rest} ->
        finalize_full_frame(rest, opts, ctx, acc)
    end
  end

  defp finalize_full_frame(rest, _opts, ctx, acc) do
    {:ok, [
      %FullFrame{
        records: :lists.reverse(acc),
        manufacturer_bytes: rest,
      } | ctx]}
  end

  #
  # Format Frame
  #
  defp parse_format_frame(<<>>, opts, ctx, acc) do
    finalize_format_frame(<<>>, opts, ctx, acc)
  end
  defp parse_format_frame(bin, opts, ctx, acc) do
    case Apl.DataRecord.Header.parse(bin, opts, ctx) do
      {:ok, header, rest} ->
        parse_format_frame(rest, opts, ctx, [header | acc])
      # just skip the idle filler
      {:special_function, :idle_filler, rest} ->
        parse_format_frame(rest, opts, ctx, acc)
      # manufacturer specific data is the rest of the APL data
      {:special_function, {:manufacturer_specific, :to_end}, rest} ->
        finalize_format_frame(rest, opts, ctx, acc)
      {:special_function, {:manufacturer_specific, :more_records_follow}, rest} ->
        finalize_format_frame(rest, opts, ctx, acc)
    end
  end

  defp finalize_format_frame(<<>>, _opts, ctx, acc) do
    {:ok, [%FormatFrame{headers: :lists.reverse(acc)} | ctx]}
  end
  #
  # Compact Frame
  #
  defp parse_compact_frame(bin, _opts, ctx, _acc) do
    {:ok, [%CompactFrame{bytes: bin} | ctx]}
  end


  # decrypt mode 5 bytes
  defp decrypt_mode_5(enc, opts, ctx) do
    {:ok, iv} = ctx_to_mode_5_iv(ctx)
    {:ok, byte_keys} = Key.from_options(opts, ctx)

    answer =
      Enum.find_value(byte_keys, fn(byte_key) ->
        case :crypto.block_decrypt(:aes_cbc, byte_key, iv, enc) do
          <<0x2f, 0x2f, rest::binary>> -> rest
          _ -> nil
        end
      end)

    case answer do
      nil -> {:error, {:no_valid_keys, byte_keys}}
      bin -> {:ok, bin}
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
