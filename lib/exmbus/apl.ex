defmodule Exmbus.Apl do

  alias Exmbus.Apl.DataRecord
  alias Exmbus.Apl.EncryptedApl
  alias Exmbus.Tpl
  alias Exmbus.Tpl.None
  alias Exmbus.Tpl.Short
  alias Exmbus.Tpl.Long

  defstruct [
    records: [],
    manufacturer_data: nil,
  ]

  @doc """
  Decode the Application Layer and return an %Apl{} struct.

  The Application Layer consists of N number of records where N >= 0,
  and some optional manufacturer specific data.

  The function assumes that the entire input is the APL layer data.

  """
  def parse(bin, opts, [%Tpl{}=tpl|_]=parsed) do
    mode = Tpl.encryption_mode(tpl)
    parse(mode, bin, opts, parsed)
  end
  # if TPL isn't the previous layer then treat it as not encrypted
  def parse(bin, opts, parsed) do
    parse({:mode, 0}, bin, opts, parsed)
  end

  @doc """
  Parse APL layer in a specific mode.
  This is used from EncryptedApl to force a {:mode, 0} after we've decrypted an encrypted
  payload, so it has to be public.
  """
  def parse({:mode, 0}, bin, opts, parsed) do
    {:ok, {records, manufacturer_data}} = parse_records(bin, [])
    apl = %__MODULE__{
      records: records,
      manufacturer_data: manufacturer_data,
    }
    {:ok, [apl | parsed]}
  end

  def parse({:mode, _}, bin, opts, [%Tpl{}=tpl | _]=parsed) do
    EncryptedApl.parse(bin, opts, parsed)
  end

  #
  # Helpers
  #
  defp parse_records(<<>>, acc) do
    # no more APL data
    {:ok, {:lists.reverse(acc), <<>>}}
  end
  defp parse_records(bin, acc) do
    case DataRecord.parse(bin) do
      {:ok, record, rest} ->
        parse_records(rest, [record | acc])
      # just skip the idle filler
      {:special_function, :idle_filler, rest} ->
        parse_records(rest, acc)
      # manufacturer specific data is the rest of the APL data
      {:special_function, {:manufacturer_specific, :to_end}, rest} ->
        {:ok, {:lists.reverse(acc), rest}}
    end
  end






  # defp decode_apl(frame_type, {:mode, 5}=mode, header, rest, %{dll: dll}=opts, parsed) do
  #   keyfn = case opts do
  #     %{keyfn: keyfn} -> keyfn
  #     %{} -> raise "frame encrypted but no :keyfn options supplied."
  #   end
  #   {enc, plain} = split_encrypted(header, rest)
  #   {:ok, plain_apl} = Apl.decode(plain)

  #   {manufacturer, identification_no, version, device, access_no} = case header do
  #     # if Short header, most info comes from DLL,
  #     %Short{access_no: access_no} ->
  #       {dll.manufacturer, dll.identification_no, dll.version, dll.device, access_no}
  #     # If long, from this header:
  #     %Long{manufacturer: m, identification_no: id, version: v, device: d, access_no: a} ->
  #       {m, id, v, d, a}
  #   end

  #   {:ok, man_bytes} = Manufacturer.encode(manufacturer)
  #   {:ok, id_bytes} = DataType.encode_type_a(identification_no, 32)

  #   iv = << man_bytes::binary, id_bytes::binary, version, device,
  #           access_no, access_no, access_no, access_no, access_no, access_no, access_no, access_no>>

  #   case keyfn.(mode, {manufacturer, identification_no, version, device}) do
  #     {:ok, keys} ->
  #       case try_mode5_keys(keys, iv, enc) do
  #         {:error, :no_key} ->
  #           {:error, {:no_key_match, keys}}
  #         {:error, reason} ->
  #           {:error, reason}
  #         {:ok, _matching_key, data} ->
  #           {:ok, encrypted_apl} = Apl.decode(data)
  #           tpl = %__MODULE__{

  #           }
  #           {:ok, tpl}
  #       end
  #     {:error, reason}=e ->
  #       {:error, {:decode_failed, {:keyfn_return, e}}}
  #     other ->
  #       raise "Decoding failed because keyfn (#{inspect keyfn}) was expected to return {:ok, keys} but returned #{inspect other}"
  #   end
  # end

end
