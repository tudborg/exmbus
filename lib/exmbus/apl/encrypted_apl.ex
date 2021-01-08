defmodule Exmbus.Apl.EncryptedApl do
  @moduledoc """
  Wrapper for encrypted data so we can tell it apart from the Apl struct.
  This is a container to indicate that bytes are encrypted and needs decrypting to get
  to the full APL.
  """

  alias Exmbus.Apl
  alias Exmbus.Tpl
  alias Exmbus.Dll.Wmbus
  alias Exmbus.Manufacturer
  alias Exmbus.DataType

  defstruct [
    encrypted_bytes: nil,
    plain_bytes: nil,
    mode: nil,
    iv: nil,
  ]

  def parse(bin, opts, [%Tpl{}=tpl | _]=parsed) do
    {enc, plain} = split_encrypted(bin, tpl)
    mode = Tpl.encryption_mode(tpl)
    {:ok, iv} = case mode do
      {:mode, 5} -> layers_to_mode_5_iv(parsed)
    end
    eapl = %__MODULE__{
      encrypted_bytes: enc,
      plain_bytes: plain,
      mode: mode,
      iv: iv,
    }
    {:ok, [eapl | parsed]}
  end

  @doc """
  Decrypt EncryptedApl from the end of a list of parsed layers and replace it with
  a regular Apl struct on success.
  """
  def decrypt([%__MODULE__{mode: {:mode, 5}, iv: iv, encrypted_bytes: enc, plain_bytes: plain} | tail_parsed], key, opts \\ [])
  when byte_size(key) == 16 do
    case :crypto.block_decrypt(:aes_cbc, key, iv, enc) do
      <<0x2f, 0x2f, _::binary>>=decrypted ->
        # treat the decrypted data as it wasn't encrypted in the first place
        Apl.parse({:mode, 0}, <<decrypted::binary, plain::binary>>, opts, tail_parsed)
      _ ->
        {:error, {:invalid_key, key}}
    end
  end

  # split APL bytes into two an encrypted and plain part based on tpl header, {encrypted, plain}
  defp split_encrypted(apl_bytes, tpl) do
    len = Tpl.encrypted_byte_count(tpl)
    <<enc::binary-size(len), plain::binary>> = apl_bytes
    {enc, plain}
  end

  # Generate the IV for mode 5 encryption
  defp layers_to_mode_5_iv([%Tpl{header: %Tpl.Short{access_no: a_no}}, %Wmbus{}=wmbus | _]=parsed) do
    %Wmbus{manufacturer: m, identification_no: i, version: v, device: d} = wmbus
    {:ok, man_bytes} = Manufacturer.encode(m)
    {:ok, id_bytes} = DataType.encode_type_a(i, 32)
    {:ok, <<man_bytes::binary, id_bytes::binary, v, d,
            a_no, a_no, a_no, a_no, a_no, a_no, a_no, a_no>>}
  end
  defp layers_to_mode_5_iv([%Tpl{header: %Tpl.Long{}=header} | _]=parsed) do
    %Tpl.Long{manufacturer: m, identification_no: id, version: v, device: d, access_no: a_no} = header
    {:ok, man_bytes} = Manufacturer.encode(m)
    {:ok, id_bytes} = DataType.encode_type_a(id, 32)
    {:ok, <<man_bytes::binary, id_bytes::binary, v, d,
            a_no, a_no, a_no, a_no, a_no, a_no, a_no, a_no>>}
  end







end
