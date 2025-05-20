defmodule CryptoTest do
  @moduledoc """
  Test the wrapper module that Exmbus uses to wrap :crypto functions.
  """

  use ExUnit.Case, async: true

  alias Exmbus.Crypto

  describe "kdf_a" do
    @master_key Base.decode16!("000102030405060708090A0B0C0D0E0F")
    @encrypted_session_key Base.decode16!("ECCF39D475D730B8284FDFDC1995D52F")
    @mac_session_key Base.decode16!("C9CD19FF5A9AAD5A6BBDA13BD2C4C7AD")
    @message_counter :binary.decode_unsigned(Base.decode16!("B30A0000"), :little)
    @meter_id Base.decode16!("78563412")

    test "Kenc - CEN/TR 17167:2018 - F.3 Security mode 7 example" do
      {:ok, ephemeral_key} =
        Crypto.kdf_a(:from_meter, :enc, @message_counter, @meter_id, @master_key)

      assert ephemeral_key == @encrypted_session_key
    end

    test "Kmac - CEN/TR 17167:2018 - F.3 Security mode 7 example" do
      {:ok, ephemeral_key} =
        Crypto.kdf_a(:from_meter, :mac, @message_counter, @meter_id, @master_key)

      assert ephemeral_key == @mac_session_key
    end
  end
end
