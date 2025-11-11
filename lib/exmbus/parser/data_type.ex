defmodule Exmbus.Parser.DataType do
  @moduledoc """
  Contains functions for working with data encoded according to EN 13757-3:2018 section 6.3.3 (Table 4)
  and specified in Annex A of same document.

  It also implements working with variable-length data (LVAR) according to same document same section (Table 5)
  """
  alias Exmbus.Parser.DataType.PeriodicDate

  import Bitwise

  @doc """
  Decode an LVAR value from binary.
  This is a variable-length-style encoding, but with a twist (as with most things in mbus),
  so it requires a bit more work than <<length, data::binary-size(length), rest::binary>>.

  It takes an optional argument `mode` which is an atom indicating what decode method to apply
  in case of LVAR 0x00–0xBF, since that can be both ISO 8859-1 encoded text, or it can be
  raw bytes in case of VIFs that need a container type.

  Currently the following are container types:
    # If VIF is from the FD extension table and is:
    # - 0bE0111011 then it's wmbus
    # - 0bE1110110 then it's manifacturer specific bytes

  The default is currently `:container` mode which just returns the bytes as a binary.
  This is what the old parser does as well, but we could a latin1 decoder in here if someone
  actually sends non-ascii text to us, which is the only case where it would be needed
  (because in elixir Strings are just binary data in UTF-8, and both Latin-1 and UTF-8 are extensions
  to ASCII, so by coincedence, if you send ASCII-only characters it will be the same in both UTF-8 and Latin-1,
  and elixir binary data and elixir strings are the same, so we don't need to do any conversion.)

      # raw bytes container
      iex> decode_lvar(<<5, "hello", 0xFF>>, :container)
      {:ok, <<"hello">>, <<0xFF>>}

      # empty container
      iex> decode_lvar(<<0, 0xFF>>, :container)
      {:ok, <<>>, <<0xFF>>}

      # empty positive BCD number
      iex> decode_lvar(<<0xC0, 0xFF>>)
      {:ok, 0, <<0xFF>>}

      # positive BCD number
      iex> decode_lvar(<<0xC1, 0x10, 0xFF>>)
      {:ok, 10, <<0xFF>>}

      # empty negative BCD number
      iex> decode_lvar(<<0xD0, 0xFF>>)
      {:ok, 0, <<0xFF>>}

      # negative BCD number
      iex> decode_lvar(<<0xD1, 0x10, 0xFF>>)
      {:ok, -10, <<0xFF>>}

      # negative multi-byte BCD number
      iex> decode_lvar(<<0xD2, 0x34, 0x12, 0xFF>>)
      {:ok, -1234, <<0xFF>>}

      # LVAR binary number
      iex> decode_lvar(<<0xE1, 123::signed-little-size(8), 0xFF>>)
      {:ok, 123, <<0xFF>>}

      # LVAR binary number
      iex> decode_lvar(<<0xE4, -123456789::signed-little-size(32), 0xFF>>)
      {:ok, -123456789, <<0xFF>>}

      iex> decode_lvar(<<5, "hel">>, :container)
      {:error, {:not_enough_bytes_for_lvar, 5, "hel"}, <<>>}

  """
  @spec decode_lvar(binary(), :container | :latin1) ::
          {:ok, binary() | integer(), binary()}
          | {:error, {:not_enough_bytes_for_lvar, non_neg_integer(), binary()}, binary()}
  # LVAR 0x00–0xBF: (0 to 191) characters 8-bit text string according to ISO/IEC 8859-1 (latin-1)
  # (If a wireless M-Bus data container is used it counts the number of bytes inside the container)
  def decode_lvar(bin, mode \\ :container)

  def decode_lvar(<<lvar, rest::binary>>, :container) when lvar < 0xC0 do
    case rest do
      <<value::binary-size(lvar), rest::binary>> ->
        {:ok, value, rest}

      _ ->
        # if we can't match LVAR amount of bytes then something is broken in the data.
        {:error, {:not_enough_bytes_for_lvar, lvar, rest}, <<>>}
    end
  end

  # LVAR 0xC0-0xC9: positive BCD number (LVAR–C0h)*2 digits, 0 to 18 digits
  def decode_lvar(<<lvar, rest::binary>>, _mode) when lvar >= 0xC0 and lvar <= 0xC9 do
    decode_type_a(rest, 8 * (lvar - 0xC0))
  end

  # LVAR 0xD0-0xD9: negative BCD number (LVAR–D0h)*2 digits, 0 to 18 digits
  def decode_lvar(<<lvar, rest::binary>>, _mode) when lvar >= 0xD0 and lvar <= 0xD9 do
    case decode_type_a(rest, 8 * (lvar - 0xD0)) do
      {:ok, value, rest} -> {:ok, -value, rest}
    end
  end

  ##
  ## NOTE: I'm actually not sure if this is how the LVAR binary numbers are supposed to be decoded.
  ## It's very unclear from the manual.
  ##

  # LVAR 0xE0-0xEF: binary number (LVAR–E0h) bytes, 0 to 15 bytes
  def decode_lvar(<<lvar, rest::binary>>, _mode) when lvar >= 0xE0 and lvar <= 0xE0F do
    decode_type_b(rest, 8 * (lvar - 0xE0))
  end

  # LVAR 0xF0-0xF4: Binary number 4*(LVAR–ECh) bytes, 16, 20, 24, 28, 32 bytes
  def decode_lvar(<<lvar, rest::binary>>, _mode) when lvar >= 0xE0 and lvar <= 0xE0F do
    decode_type_b(rest, 8 * 4 * (lvar - 0xEC))
  end

  # LVAR 0xF5: 48 bytes
  def decode_lvar(<<0xF5, rest::binary>>, _mode) do
    decode_type_b(rest, 8 * 48)
  end

  # LVAR 0xF6: 64 bytes
  def decode_lvar(<<0xF6, rest::binary>>, _mode) do
    decode_type_b(rest, 8 * 64)
  end

  # encoder for simple lvars
  def encode_lvar(b) when is_binary(b) and byte_size(b) < 0xC0 do
    {:ok, <<byte_size(b), b::binary>>}
  end

  def encode_lvar(i) when is_integer(i) do
    raise "encoding an integer as BCD in lvar not implemented"
  end

  ##
  ## Type decoders
  ## Specification from Annex A of EN 13757-3:2018
  ##

  @doc """
  Type A
  BCD integer.
  if MSB 0xF then the remanining digits are interpreted as a negative number

      iex> decode_type_a(<<0x34, 0x12, 0xFF>>, 16)
      {:ok, 1234, <<0xFF>>}

      iex> decode_type_a(<<0x23, 0xF1, 0xFF>>, 16)
      {:ok, -123, <<0xFF>>}

      iex> decode_type_a(<<0x23, 0xC1, 0xFF>>, 16)
      {:ok, {:invalid, {:type_a, 0xC123}}, <<0xFF>>}
  """
  @spec decode_type_a(binary(), integer()) :: {:ok, integer() | {:invalid, any()}, binary()}
  def decode_type_a(bin, bitsize) do
    # TODO: performance of using digits/undigits.
    <<bcd::little-size(bitsize), rest::binary>> = bin

    {sign, digits} =
      case Integer.digits(bcd, 16) do
        [0xF | digits] -> {-1, digits}
        digits -> {1, digits}
      end

    if Enum.any?(digits, &(&1 > 0x9 and &1 <= 0xF)) do
      {:ok, {:invalid, {:type_a, bcd}}, rest}
    else
      case {sign, Integer.undigits(digits)} do
        {1, value} -> {:ok, value, rest}
        {-1, value} -> {:ok, -value, rest}
      end
    end
  end

  def encode_type_a(value, bitsize) do
    bcd =
      value
      |> Integer.digits()
      |> Integer.undigits(16)

    {:ok, <<bcd::little-size(bitsize)>>}
  end

  @doc """
  Type B
  Signed little-endian integer

      iex> decode_type_b(<< -1234::signed-little-size(16), 0xFF>>, 16)
      {:ok, -1234, <<0xFF>>}
  """
  @spec decode_type_b(binary(), integer()) :: {:ok, integer(), binary()}
  def decode_type_b(bin, bitsize) do
    <<value::signed-little-size(bitsize), rest::binary>> = bin
    {:ok, value, rest}
  end

  def encode_type_b(data, bitsize) do
    {:ok, <<data::signed-little-size(bitsize)>>}
  end

  @doc """
  Type C
  Unsigned little-endian integer

      iex> decode_type_c(<<1234::unsigned-little-size(16), 0xFF>>, 16)
      {:ok, 1234, <<0xFF>>}
  """
  @spec decode_type_c(binary(), integer()) :: {:ok, non_neg_integer(), binary()}
  def decode_type_c(bin, bitsize) do
    <<value::unsigned-little-size(bitsize), rest::binary>> = bin
    {:ok, value, rest}
  end

  def encode_type_c(data, bitsize) do
    {:ok, <<data::unsigned-little-size(bitsize)>>}
  end

  @doc """
  Type D
  Bool list from bits.

      iex> decode_type_d(<<0b0000111111110000::unsigned-little-size(16), 0xFF>>, 16)
      {:ok, [false, false, false, false, true, true, true, true, true, true, true, true, false, false, false, false], <<0xFF>>}
  """
  @spec decode_type_d(binary(), integer()) :: {:ok, [boolean()], binary()}
  def decode_type_d(bin, bitsize) do
    <<i::unsigned-little-size(bitsize), rest::binary>> = bin
    # re-encode to bitstring now that we have the "right" order
    {:ok, bitstring_to_bool_list(<<i::size(bitsize)>>), rest}
  end

  def encode_type_d(data, bitsize) do
    <<i::size(bitsize)>> = bool_list_to_bitstring(data)
    {:ok, <<i::unsigned-little-size(bitsize)>>}
  end

  @doc """
  Type F
  Convert 32 bits to a NaiveDateTime with seconds truncated to 0.
  (Type F is a date+time without seconds specified, but we just truncate. Good Enough :tm:)

      iex> decode_type_f(<<0b00::2, 10::6, 0::1, 0::2, 20::5, 0b101::3, 1::5, 0b0010::4, 2::4, 0xFF>>)
      {:ok, ~N[2021-02-01 20:10:00], <<0xFF>>}
  """
  @spec decode_type_f(binary()) ::
          {:ok, NaiveDateTime.t() | :invalid, rest :: binary()}
          | {:error, {:unsupported_feature, :data_type_f_with_periodicity}, rest :: binary()}
          | {:error, naive_datetime_new_error_reason :: atom(), rest :: binary()}
  # TYPE F, Date+Time (no seconds) (32 bit)
  def decode_type_f(
        # invalid, reserved, minute
        <<
          iv::1,
          _res1::1,
          minute::6,
          # summertime, hundred year, hour, # NOTE: We ignore summer time in this function!
          _su::1,
          hundred_year::2,
          hour::5,
          # year (LSB), day,
          year_lsb::3,
          day::5,
          # year (MSB), month
          year_msb::4,
          month::4,
          rest::binary
        >>
      ) do
    year = year_msb <<< 3 ||| year_lsb

    year =
      case hundred_year do
        # Compatibility hack as recommended in the manual in Table A.5 — Type F: Date and time (CP32)
        0 when year <= 80 -> 2000 + year
        h -> 1900 + 100 * h + year
      end

    # the standard supports indicating periodicity in this type but that's really annoying
    # to do since it doesn't fit in our normal type for time.
    # instead, I guard for it and raise if we see it. I suspect noone actually uses this feature.
    has_periodicity = minute == 63 or hour == 31 or day == 0 or month == 15 or year == 127

    cond do
      iv == 1 ->
        # If "invalid" is set, we return the :invalid atom, because apparently
        # meters will intentionally send an invalid record.
        {:ok, :invalid, rest}

      has_periodicity ->
        # We don't currently properly support representing periodicity, so we return an error:
        {:error, {:unsupported_feature, :data_type_f_with_periodicity}, rest}

      true ->
        # try to put all of that into a NaiveDateTime
        case NaiveDateTime.new(year, month, day, hour, minute, 0) do
          {:ok, ndt} -> {:ok, ndt, rest}
          {:error, reason} -> {:error, reason, rest}
        end
    end
  end

  def encode_type_f(%NaiveDateTime{} = ndt) do
    # NOTE: We ignore summer time in this function!
    hundred_year = div(ndt.year - 1900, 100)
    year = rem(ndt.year, 100)

    year_msb = year >>> 3
    year_lsb = year &&& 0b111

    {:ok,
     <<0::1, 0::1, ndt.minute::6, 0::1, hundred_year::2, ndt.hour::5, year_lsb::3, ndt.day::5,
       year_msb::4, ndt.month::4>>}
  end

  @doc """
  Type G
  Convert 16 bits to a Date

      iex> decode_type_g(<<0b101::3, 1::5, 0b0010::4, 2::4, 0xFF>>)
      {:ok, ~D[2021-02-01], <<0xFF>>}

      iex> decode_type_g(<<0xFF, 0xFF, 0xFF>>)
      {:ok, :invalid, <<0xFF>>}

      iex> decode_type_g(<<0b111_00001, 0b1111_0001, 0xFF>>)
      {:ok, %PeriodicDate{year: nil, month: 1, day: 1}, <<0xFF>>}

  """
  @spec decode_type_g(binary()) :: {:ok, Date.t() | PeriodicDate.t() | :invalid, rest :: binary()}
  # TYPE G, date (16 bit)
  def decode_type_g(<<0xFF, 0xFF, rest::binary>>) do
    # manual Table A.6 — Type G: Date (CP16) "A value of FFh in both bytes (that means FFFFh) shall be interpreted as invalid."
    {:ok, :invalid, rest}
  end

  def decode_type_g(<<year_lsb::3, day::5, year_msb::4, month::4, rest::binary>>) do
    year = year_msb <<< 3 ||| year_lsb

    cond do
      # The spec isn't clear about what happens outside of the allowed ranges,
      # so we just treat them as invalid values just as with 0xFFFF above.
      year > 99 and year < 127 ->
        {:ok, :invalid, rest}

      month < 1 or (month > 12 and month != 15) ->
        {:ok, :invalid, rest}

      day > 31 and day != 0 ->
        {:ok, :invalid, rest}

      # the standard supports indicating periodicity in this type but that's really annoying
      # to do since it doesn't fit in our normal type for time.
      # We return a special struct for it, so that the user can handle it properly.
      day == 0 or month == 15 or year == 127 ->
        day = if day == 0, do: nil, else: day
        month = if month == 15, do: nil, else: month
        year = if year == 127, do: nil, else: interpret_type_g_year(year)

        case PeriodicDate.new(year, month, day) do
          {:ok, periodic_date} -> {:ok, periodic_date, rest}
        end

      true ->
        case Date.new(interpret_type_g_year(year), month, day) do
          {:ok, date} -> {:ok, date, rest}
          {:error, reason} -> {:error, reason, rest}
        end
    end
  end

  defp interpret_type_g_year(year) do
    case year do
      year when year > 80 -> 1900 + year
      # Compatibility hack as recommended in the manual in Table A.5 — Type F: Date and time (CP32)
      year -> 2000 + year
    end
  end

  @doc """
  Encode a Date to type G (16 bit)

    # <<161, 34>> = <<5::3, 1::5, 2::4, 2::4>>
    iex> {:ok, <<161, 34>>} = encode_type_g(~D[2021-02-01])
  """
  def encode_type_g(%Date{year: year, month: month, day: day}) do
    # See note on compatibility as recommended in the manual in Table A.5 — Type F: Date and time (CP32)
    year =
      if year >= 2000 do
        year - 2000
      else
        year - 1900
      end

    year_msb = year >>> 3 &&& 0b1111
    year_lsb = year &&& 0b111
    {:ok, <<year_lsb::3, day::5, year_msb::4, month::4>>}
  end

  @spec decode_type_h(binary()) ::
          {:ok, float() | :nan | :positive_infinity | :negative_infinity, rest :: binary()}
  # TYPE H IEEE Float.
  # NOTE: erlang doesn't do IEEE floats, so we don't have NaN and Infinity in our floats.
  # we do the next best thing and return atoms instead.
  def decode_type_h(<<value::little-float-size(32), rest::binary>>), do: {:ok, value, rest}
  # Positive infinity sign=1, exponent=all 1s, fraction=all 0s
  def decode_type_h(<<0b0_11111111_00000000000000000000000::little-size(32), rest::binary>>),
    do: {:ok, :positive_infinity, rest}

  # Negative infinity sign=1, exponent=all 1s, fraction=all 0s
  def decode_type_h(<<0b1_11111111_00000000000000000000000::little-size(32), rest::binary>>),
    do: {:ok, :negative_infinity, rest}

  # NaN sign=_, exponent=all 1s, fraction=Anything but all 0s
  # we just catch-all and assign NaN.
  def decode_type_h(<<_::32, rest::binary>>), do: {:ok, :nan, rest}

  def encode_type_h(:nan), do: {:ok, <<0b0_11111111_00000000000000000000001::little-size(32)>>}

  def encode_type_h(:positive_infinity),
    do: {:ok, <<0b0_11111111_00000000000000000000000::little-size(32)>>}

  def encode_type_h(:negative_infinity),
    do: {:ok, <<0b1_11111111_00000000000000000000000::little-size(32)>>}

  def encode_type_h(value) when is_integer(value), do: encode_type_h(value / 1)
  def encode_type_h(value) when is_float(value), do: {:ok, <<value::little-float-size(32)>>}

  @doc """
  Type I
  Convert 48 bits to a NaiveDateTime
  (This isn't 1:1 with spec but without creating a new type for DateTime this is the closest we get)
  """
  @spec decode_type_i(binary()) ::
          {:ok, NaiveDateTime.t(), rest :: binary()}
          | {:error, naive_datetime_new_error_reason :: atom(), rest :: binary()}
  # TYPE I, date+time, year down to second (local time) (48 bit)
  def decode_type_i(
        # leap year, time during daylight savings, second
        <<
          _leap_year::1,
          _tdds::1,
          second::6,
          # invalid, daylight savings deviation sign (0 is -, 1 is +), minute
          iv::1,
          _dst_sign::1,
          minute::6,
          # day of week, hour,
          _dow::3,
          hour::5,
          # year (LSB), day,
          year_lsb::3,
          day::5,
          # year (MSB), month
          year_msb::4,
          month::4,
          # daylight savings deviation in hours, week (0 is "not specified")
          _dst_dev_hour::2,
          _week::6,
          rest::binary
        >>
      ) do
    year =
      case year_msb <<< 3 ||| year_lsb do
        year when year > 80 -> 1900 + year
        # Compatibility hack as in type F and G (the manual doesn't specify this for type I but if we don't it doesn't make sense)
        year -> 2000 + year
      end

    # the standard supports indicating periodicity in this type but that's really annoying
    # to do since it doesn't fit in our normal type for time.
    # instead, I guard for it and raise if we see it. I suspect noone actually uses this feature.
    has_periodicity = second == 63 or minute == 63 or hour == 31

    if has_periodicity,
      do:
        raise(
          "timestamp of Type I indicated periodicity but that is not supported by this library. Contact author."
        )

    # Type I doesn't have "every N" for day+month+year, instead it has "not specified" which again,
    # I don't think anyone in their right mind would use like this, so just guarding against it.
    # I'm assuming this is to only specify week number and not day or month.
    has_not_specified = day == 0 or month == 0 or year == 127

    if has_not_specified,
      do:
        raise(
          "timestamp of Type I indicated a \"not specified\" value (either day month or year) but that is not supported by this library. Contact author."
        )

    # if the date is marked invalid raise. I've not seen this in the wild.
    if iv == 1,
      do: raise("time marked invalid which this library doesn't support. Contact author.")

    # try to put all of that into a NaiveDateTime
    case NaiveDateTime.new(year, month, day, hour, minute, second) do
      {:ok, ndt} -> {:ok, ndt, rest}
      {:error, reason} -> {:error, reason, rest}
    end
  end

  def encode_type_i(%NaiveDateTime{}) do
    raise "encode type i not implemented"
  end

  @doc """
  Type J
  Convert 24 bits to a Time

      iex> decode_type_j(<<59, 48, 11, 0xFF>>)
      {:ok, ~T[11:48:59], <<0xFF>>}
  """
  @spec decode_type_j(binary()) ::
          {:ok, Time.t(), rest :: binary()}
          | {:error, time_new_error_reason :: atom(), rest :: binary()}
  # TYPE J, Time of day (local time) (24 bit)
  def decode_type_j(<<second, minute, hour, rest::binary>>) do
    case Time.new(hour, minute, second) do
      {:ok, t} -> {:ok, t, rest}
      {:error, reason} -> {:error, reason, rest}
    end
  end

  def encode_type_j(%Time{}) do
    raise "encode type j not implemented"
  end

  def decode_type_k(_bin) do
    raise "Type k (Daylight savings) not implemented"
  end

  def encode_type_k(_) do
    raise "type k not implemented"
  end

  def decode_type_l(_bin) do
    raise "Type L (Listening window management) not implemented"
  end

  def encode_type_l(_) do
    raise "encode type L not implemented"
  end

  # Type M: Date and time (CP_LVAR)
  # The time format Type M contains always the coordinated universal time.
  # A deviation of the local time zone to UTC can be considered in the field time offset.
  # Daylight savings shall not be used in this time format.
  def decode_type_m(_bin) do
    raise "Type M (Compound CP_LVAR: Date and time/duration) not implemented"

    # returns DateTime
  end

  def encode_type_m(_) do
    raise "encode type m not implemented"
  end

  # convert bitstring to list of bools.
  # @doc """
  # Convert a bitstring <<0b001100::size(6)>> to [false, false, true, true, false, false]

  #   iex> bitstring_to_bool_list(<<0b001100::size(6)>>)
  #   [false, false, true, true, false, false]

  #   iex> bitstring_to_bool_list(<<0b0000000011111111::size(16)>>)
  #   [false, false, false, false, false, false, false, false, true, true, true, true, true, true, true, true]
  # """
  # optimized for 8-bit 0x00 byte.
  # It's quite a common case that most flags are 0, so we can optimize for that.
  # this significantly reduces the amount of work needed to decode a bitstring in the common case.
  defp bitstring_to_bool_list(<<0x00, rest::binary>>) do
    [false, false, false, false, false, false, false, false | bitstring_to_bool_list(rest)]
  end

  defp bitstring_to_bool_list(<<>>), do: []

  defp bitstring_to_bool_list(<<0::1, rest::bitstring>>),
    do: [false | bitstring_to_bool_list(rest)]

  defp bitstring_to_bool_list(<<1::1, rest::bitstring>>),
    do: [true | bitstring_to_bool_list(rest)]

  defp bool_list_to_bitstring([]), do: <<>>

  defp bool_list_to_bitstring([false | rest]),
    do: <<0::1, bool_list_to_bitstring(rest)::bitstring>>

  defp bool_list_to_bitstring([true | rest]),
    do: <<1::1, bool_list_to_bitstring(rest)::bitstring>>
end
