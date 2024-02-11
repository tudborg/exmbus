defmodule Exmbus.Parser.Apl do
  alias Exmbus.Parser.Context
  alias Exmbus.Parser.Apl.DataRecord
  alias Exmbus.Parser.Apl.DataRecord.InvalidDataRecord
  alias Exmbus.Parser.Tpl
  alias Exmbus.Key
  alias Exmbus.Parser.Dll.Wmbus
  alias Exmbus.Parser.Manufacturer
  alias Exmbus.Parser.Tpl.Device
  alias Exmbus.Parser.DataType
  alias Exmbus.Parser.Apl.FullFrame
  alias Exmbus.Parser.Apl.FormatFrame
  alias Exmbus.Parser.Apl.CompactFrame

  defmodule Raw do
    @moduledoc """
    Contains the raw APL and encryption mode.
    This struct is usually an intermedidate struct
    and will not show in the final parse stack unless options are given
    to not parse the APL.
    """
    defstruct encrypted_bytes: nil,
              plain_bytes: nil,
              mode: nil
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

  # It is possible to disable parsing of the APL by setting parse_apl: false in options.
  defp parse_apl(%{parse_apl: false}, %{apl: %Raw{mode: 0, plain_bytes: _}} = ctx),
    do: {:ok, ctx, <<>>}

  defp parse_apl(opts, %{apl: %Raw{mode: 0, plain_bytes: bin, encrypted_bytes: <<>>}} = ctx) do
    parse_records(bin, opts, ctx)
  end

  # when encryption mode is 5 and key option is set:
  defp parse_apl(
         %{key: _} = opts,
         %{apl: %Raw{mode: 5, encrypted_bytes: enc, plain_bytes: plain}} = ctx
       ) do
    with {:ok, decrypted} <- decrypt_mode_5(enc, opts, ctx) do
      parse_apl(
        opts,
        Context.layer(ctx, :apl, %Raw{
          mode: 0,
          plain_bytes: <<decrypted::binary, plain::binary>>,
          encrypted_bytes: <<>>
        })
      )
    end
  end

  # when no key is supplied or we don't understand how to decrypt, return parse context
  defp parse_apl(%{}, %{apl: %Raw{}} = ctx) do
    {:ok, ctx, <<>>}
  end

  # assume decrypted apl bytes as first argument, parse data fields
  # an return an {:ok, Apl+ctx}
  defp parse_records(bin, opts, %{tpl: %Tpl{frame_type: :full_frame}} = ctx) do
    # NOTE:
    # Should we possibly calculate the format signature here and attach it to the FullFrame struct?
    # That way we don't need the expensive unparse operation to get the format signature,
    # BUT we'd calculate it on every single parse? Option to turn off maybe?
    parse_full_frame(bin, opts, ctx, [])
  end

  defp parse_records(bin, opts, %{tpl: %Tpl{frame_type: :format_frame}} = ctx) do
    parse_format_frame(bin, opts, ctx)
  end

  defp parse_records(bin, opts, %{tpl: %Tpl{frame_type: :compact_frame}} = ctx) do
    parse_compact_frame(bin, opts, ctx)
  end

  #
  # Parse full-frame records:
  #
  defp parse_full_frame(<<>>, opts, ctx, acc) do
    finalize_full_frame(<<>>, opts, ctx, acc)
  end

  defp parse_full_frame(bin, opts, ctx, acc) do
    case DataRecord.parse(bin, opts, ctx) do
      {:ok, %DataRecord{} = data_record, rest} ->
        parse_full_frame(rest, opts, ctx, [data_record | acc])

      {:ok, %InvalidDataRecord{} = data_record, rest} ->
        parse_full_frame(rest, opts, ctx, [data_record | acc])

      # just skip the idle filler
      {:special_function, :idle_filler, rest} ->
        parse_full_frame(rest, opts, ctx, acc)

      # manufacturer specific data is the rest of the APL data
      {:special_function, {:manufacturer_specific, :to_end}, rest} ->
        finalize_full_frame(rest, opts, ctx, acc)

      {:special_function, {:manufacturer_specific, :more_records_follow}, rest} ->
        finalize_full_frame(rest, opts, ctx, acc)

      {:error, _reason, _rest} = e ->
        e
    end
  end

  defp finalize_full_frame(rest, _opts, ctx, acc) do
    full_frame = %FullFrame{
      records: Enum.reverse(acc),
      manufacturer_bytes: rest
    }

    {:ok, Context.layer(ctx, :apl, full_frame), <<>>}
  end

  #
  # Format Frame
  #

  defp parse_format_frame(<<len, format_signature::little-size(16), rest::binary>>, opts, ctx) do
    _parse_format_frame({len, format_signature}, rest, opts, ctx, [])
  end

  defp _parse_format_frame(ff_header, <<>>, opts, ctx, acc) do
    finalize_format_frame(ff_header, <<>>, opts, ctx, acc)
  end

  defp _parse_format_frame(ff_header, bin, opts, ctx, acc) do
    case DataRecord.Header.parse(bin, opts, ctx) do
      {:ok, header, rest} ->
        _parse_format_frame(ff_header, rest, opts, ctx, [header | acc])

      # just skip the idle filler
      {:special_function, :idle_filler, rest} ->
        _parse_format_frame(ff_header, rest, opts, ctx, acc)

      # manufacturer specific data is the rest of the APL data
      {:special_function, {:manufacturer_specific, :to_end}, rest} ->
        finalize_format_frame(ff_header, rest, opts, ctx, acc)

      {:special_function, {:manufacturer_specific, :more_records_follow}, rest} ->
        finalize_format_frame(ff_header, rest, opts, ctx, acc)
    end
  end

  # TODO: should we check length?
  defp finalize_format_frame({_len, format_signature}, <<>>, opts, ctx, acc) do
    full_frame = %FormatFrame{
      headers: Enum.reverse(acc)
    }

    check_result =
      if Map.get(opts, :verify_format_signature, true) do
        case FormatFrame.format_signature(full_frame) do
          {:ok, ^format_signature} ->
            :ok

          {:ok, differing_format_signature} ->
            {:error,
             {:format_signature_mismatch,
              %{expected: format_signature, got: differing_format_signature}}, ctx}
        end
      end

    with :ok <- check_result do
      {:ok, Context.layer(ctx, :apl, full_frame), <<>>}
    end
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

    with {:ok, byte_keys} <- Key.get(opts, ctx) do
      answer =
        Enum.find_value(byte_keys, fn
          byte_key when byte_size(byte_key) == 16 ->
            case :crypto.crypto_one_time(:aes_cbc, byte_key, iv, enc, false) do
              <<0x2F, 0x2F, rest::binary>> -> {:ok, rest}
              # not the valid key
              _ -> nil
            end

          byte_key ->
            {:error, {:invalid_key, {:not_16_bytes, byte_key}}, ctx}
        end)

      case answer do
        {:ok, _bin} = ok -> ok
        {:error, _reason, _ctx} = e -> e
        nil -> {:error, {:mode_5_decryption_failed, byte_keys}, ctx}
      end
    else
      {:error, e} ->
        {:error, e, ctx}
    end
  end

  # append a Raw struct to the parse stack
  defp append_raw(bin, _opts, %{tpl: %Tpl{} = tpl} = ctx) do
    {:mode, m} = Tpl.encryption_mode(tpl)
    {:ok, enclen} = Tpl.encrypted_byte_count(tpl)
    <<enc::binary-size(enclen), plain::binary>> = bin

    {:ok, Context.layer(ctx, :apl, %Raw{mode: m, encrypted_bytes: enc, plain_bytes: plain})}
  end

  defp append_raw(bin, _opts, ctx) do
    {:ok,
     Context.layer(ctx, :apl, %Raw{
       mode: 0,
       encrypted_bytes: <<>>,
       plain_bytes: bin
     })}
  end

  # Generate the IV for mode 5 encryption
  defp ctx_to_mode_5_iv(%{tpl: %Tpl{header: %Tpl.Short{access_no: a_no}}, dll: %Wmbus{} = wmbus}) do
    %Wmbus{manufacturer: m, identification_no: i, version: v, device: d} = wmbus
    {:ok, man_bytes} = Manufacturer.encode(m)
    {:ok, id_bytes} = DataType.encode_type_a(i, 32)
    {:ok, device_byte} = Device.encode(d)

    {:ok,
     <<man_bytes::binary, id_bytes::binary, v, device_byte::binary, a_no, a_no, a_no, a_no, a_no,
       a_no, a_no, a_no>>}
  end

  defp ctx_to_mode_5_iv(%{tpl: %Tpl{header: %Tpl.Long{} = header}}) do
    %Tpl.Long{manufacturer: m, identification_no: id, version: v, device: d, access_no: a_no} =
      header

    {:ok, man_bytes} = Manufacturer.encode(m)
    {:ok, id_bytes} = DataType.encode_type_a(id, 32)
    {:ok, device_byte} = Device.encode(d)

    {:ok,
     <<man_bytes::binary, id_bytes::binary, v, device_byte::binary, a_no, a_no, a_no, a_no, a_no,
       a_no, a_no, a_no>>}
  end
end
