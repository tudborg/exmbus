defmodule Exmbus.Parser.Apl.DataRecord.ValueInformationBlock.ErrorCode do
  @moduledoc """
  Decode/Encode error codes for the value information block (VIB) of a data record.
  """

  # Section 6.4.8 - Table 18 - Codes for record errors
  # DIF errors:
  def decode(0b0_0000), do: {:ok, :none}
  def decode(0b0_0001), do: {:ok, :too_many_difes}
  def decode(0b0_0010), do: {:ok, :storage_number_not_implemented}
  def decode(0b0_0011), do: {:ok, :unit_number_not_implemented}
  def decode(0b0_0100), do: {:ok, :tariff_number_not_implemented}
  def decode(0b0_0101), do: {:ok, :function_not_implemented}
  def decode(0b0_0110), do: {:ok, :data_class_not_implemented}
  def decode(0b0_0111), do: {:ok, :data_size_not_implemented}
  def decode(0b0_1000), do: {:error, {:reserved, 0b0_1000}}
  def decode(0b0_1001), do: {:error, {:reserved, 0b0_1001}}
  # VIF errors
  def decode(0b0_1010), do: {:error, {:reserved, 0b0_1010}}
  def decode(0b0_1011), do: {:ok, :too_many_vifes}
  def decode(0b0_1100), do: {:ok, :illegal_vif_group}
  def decode(0b0_1101), do: {:ok, :illegal_vif_exponent}
  def decode(0b0_1111), do: {:ok, :unimplemented_action}

  def decode(n) when n >= 0b1_0000 and n <= 0b1_0100,
    do: raise("error code #{n} not used for record errors")

  # Data errors
  def decode(0b1_0101), do: {:ok, :no_data_available}
  def decode(0b1_0110), do: {:ok, :data_overflow}
  def decode(0b1_0111), do: {:ok, :data_underflow}
  def decode(0b1_1000), do: {:ok, :data_error}
  def decode(n) when n >= 0b1_1001 and n <= 0b1_1011, do: {:error, {:reserved, n}}
  # Other errors
  def decode(0b1_1100), do: {:ok, :premature_end_of_record}
end
