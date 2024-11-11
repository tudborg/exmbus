defmodule Exmbus.Parser.Apl.DataRecord.CompactProfile do
  @moduledoc """
  This module provides functions for working with compact profiles.

  Compact Profile is a way to encode multiple values into a single data record
  for efficient transfer, typically because there is an even spacing between
  the values (e.g. monthly data for last 12 months)

  There are 3 types of compact profiles described in Annex F of EN 13757-3:2018.

  - "Compact Profile with register numbers"
  - "Compact Profile"
  - "Inverse Compact Profile"

  The compact profile data layout is described as follows:

  > The first byte (spacing control byte, Tables E.6 and F.7) of this variable length record structure contains
  > the data size of each individual element in the lower four bits (as in the lower nibble of the DIF definitions,
  > but excluding variable length elements). The next higher two bits signal the time spacing units (00b = sec,
  > 01b = min, 10b = hours and 11b = days). The highest two bits signal the increment mode of the profile
  > (00b = absolute value (signed), 01, = positive (unsigned) increments (all differences ≥ 0),
  > 10b = negative (unsigned) increments (all differences ≤ 0, 11b = signed difference, with: difference = younger value minus older value).
  > All values of the profile are initially preset with the coding for "illegal",
  > e.g. -128 for signed byte, 255 for unsigned byte, -32768 for signed word, etc. (refer toAnnex A, type B and C).
  > Invalid values shall also be used in case of an overflow of an incremental value.

  Compact Profiles are automatically expanded by default.
  This can be disabled with the option `expand_compact_profiles: false` in the options map.
  """
  alias Exmbus.Parser.Context
  alias Exmbus.Parser.Apl.DataRecord.CompactProfile.CompactProfileHeader
  alias Exmbus.Parser.Apl.DataRecord

  @doc """
  Return true if the record is a compact profile record. false otherwise.
  """
  def is_compact_profile?(%DataRecord{header: %{vib: %{extensions: extensions}}}) do
    Keyword.has_key?(extensions, :compact_profile)
  end

  @doc """
  Expand a compact profile record into the given context.
  The compact profile record will be removed from the context's records, and replaced with the
  derived records from the compact profile.
  """
  @spec expand_compact_profile(DataRecord.t(), Context.t()) ::
          {:ok, Context.t()} | {:error, term()}
  def expand_compact_profile(record, ctx) do
    with {:ok, additional_records} <- compact_profile_records(record, ctx.apl.records) do
      new_records =
        ctx.apl.records
        |> Enum.flat_map(fn
          ^record -> additional_records
          other -> [other]
        end)

      {:continue, Context.merge(ctx, apl: %{ctx.apl | records: new_records})}
    end
  end

  @doc """
  Given a compact profile record, and a list of records to search for base records,
  expand the compact profile record into a list of records.
  The returned list only contains the expanded reocrds, not the compact profile record itself,
  and not anything from the records in the second argument.
  """
  @spec compact_profile_records(DataRecord.t(), [DataRecord.t()]) ::
          {:ok, [DataRecord.t()]} | {:error, term()}
  def compact_profile_records(%DataRecord{} = record, all_records) when is_list(all_records) do
    case Keyword.get(record.header.vib.extensions, :compact_profile) do
      nil ->
        {:error, {:record_not_compact_profile, record}}

      :compact_profile ->
        compact_profile_records(:compact_profile, record, all_records)

      :inverse ->
        compact_profile_records(:inverse, record, all_records)

      :with_register_numbers ->
        {:error, {:not_implemented, {:compact_profile_with_register_numbers, record}}}
    end
  end

  defp compact_profile_records(profile_type, %DataRecord{} = record, all_records) do
    # parse the compact profile header
    {:ok, header, rest} = CompactProfileHeader.parse(record.data)
    # and parse the profile data according to the header
    {:ok, values} = parse_data(header, rest)

    # Now we attempt to locate the base value and base time (base value optional when increment mode = absolute)

    base_time_record = find_base_time_record(record, all_records)
    base_value_record = find_base_value_record(record, all_records)

    # if no base value is found, we construct one from the profile record instead:
    base_value_record =
      with nil <- base_value_record do
        vib = %{
          record.header.vib
          | extensions: Keyword.delete(record.header.vib.extensions, :compact_profile)
        }

        %DataRecord{record | data: nil, header: %{record.header | vib: vib}}
      end

    # unfold the values into a list of time and value records.
    unfold(values, profile_type, header, base_time_record, base_value_record, [])
  end

  defp find_base_time_record(record, all_records) do
    # the base time is connected via the storage number of the record.
    # so we need to locate a record with the same storage number as the profile record,
    # and of a coding type of F, G, I, J, M (date/time codings)
    Enum.find(all_records, fn r ->
      record.header.dib.storage == r.header.dib.storage and
        r.header.coding in [:type_f, :type_g, :type_i, :type_j, :type_m]
    end)
  end

  defp find_base_value_record(record, all_records) do
    # The base value is connected with the profile record via storage-, tariff-, subunit and VIF/VIFEx
    # so we need to locate a record with the same storage-, tariff-, subunit and
    # VIF/VIFEx as the profile record (apart from the compact_profile extension ofc)
    # vib_needle is the vib value we are searching for in the records
    vib_needle = %{
      record.header.vib
      | extensions: Keyword.delete(record.header.vib.extensions, :compact_profile)
    }

    Enum.find(all_records, fn r ->
      record.header.dib.storage == r.header.dib.storage and
        record.header.dib.tariff == r.header.dib.tariff and
        record.header.dib.device == r.header.dib.device and
        r.header.vib == vib_needle
    end)
  end

  defp unfold([], _profile_type, _header, _time_record, _value_record, acc) do
    {:ok, Enum.reverse(acc)}
  end

  defp unfold([value | values], profile_type, header, time_record, value_record, acc) do
    with {:ok, time} <- shift_time_record(profile_type, header.spacing, time_record),
         {:ok, data} <- shift_value_record(profile_type, header, value, value_record) do
      case header.increment_mode do
        # if the increment mode is absolute_value, we keep the value_record as the base record,
        # but set it's storage +1
        :absolute_value ->
          absolute_value_record =
            set_data_and_storage(value_record, value_record.data, data.header.dib.storage + 1)

          unfold(values, profile_type, header, time, absolute_value_record, [data, time | acc])

        # if the increment mode is increments, we use our new data as the base record:
        :increments ->
          unfold(values, profile_type, header, time, data, [data, time | acc])

        # if the increment mode is decrements, we use our new data as the base record:
        :decrements ->
          unfold(values, profile_type, header, time, data, [data, time | acc])

        # if the increment mode is signed_difference, we use our new data as the base record:
        :signed_difference ->
          unfold(values, profile_type, header, time, data, [data, time | acc])
      end
    end

    # recurse
  end

  @doc """
  Given a CompactProfileHeader and the profile data (as a binary), parse the values
  according to the header and return a list of parsed values.
  """
  def parse_data(compact_profile_header, bin) do
    parse_data(compact_profile_header, bin, [])
  end

  # parse the profile data according to the header, calling into the normal DataRecord.parse_data
  defp parse_data(%CompactProfileHeader{} = _header, <<>>, acc) do
    {:ok, Enum.reverse(acc)}
  end

  defp parse_data(%CompactProfileHeader{} = header, bin, acc) do
    # since the DIB and CompactProfileHeader share the relevant field names,
    # we can use the CompactProfileHeader as a fake DIB to parse the data.
    with {:ok, value, rest} <- DataRecord.parse_data(%{coding: header.coding, dib: header}, bin) do
      parse_data(header, rest, [value | acc])
    end
  end

  #
  # Shift a time record according to the spacing of the compact profile
  #
  defp shift_time_record(profile_type, spacing, %DataRecord{} = record) do
    duration =
      case spacing do
        {n, :second} -> Duration.new!(second: n)
        {n, :minute} -> Duration.new!(minute: n)
        {n, :hour} -> Duration.new!(hour: n)
        {n, :day} -> Duration.new!(day: n)
        {n, :month} -> Duration.new!(month: n)
      end

    # flip time direction if profile type is inverse:
    duration = if profile_type == :inverse, do: Duration.negate(duration), else: duration

    # depending on the record data type, we need to shift the data differently
    shifted_data =
      case record.data do
        %Date{} ->
          record.data |> Date.shift(duration)

        %NaiveDateTime{} ->
          record.data |> NaiveDateTime.shift(duration)

        %DateTime{time_zone: tz} ->
          record.data |> NaiveDateTime.shift(duration) |> DateTime.from_naive(tz)
      end

    {:ok, set_data_and_storage(record, shifted_data, record.header.dib.storage + 1)}
  end

  defp shift_value_record(profile_type, header, value, %DataRecord{} = record) do
    new_data =
      case header.increment_mode do
        :absolute_value ->
          value

        :signed_difference ->
          if profile_type == :inverse, do: record.data - value, else: record.data + value

        :increments ->
          if profile_type == :inverse, do: record.data - value, else: record.data + value

        :decrements ->
          if profile_type == :inverse, do: record.data + value, else: record.data - value
      end

    {:ok, set_data_and_storage(record, new_data, record.header.dib.storage + 1)}
  end

  # increment the storage number (default: by +1)
  defp set_data_and_storage(record, data, storage) do
    %{
      record
      | data: data,
        header: %{record.header | dib: %{record.header.dib | storage: storage}}
    }
  end
end
