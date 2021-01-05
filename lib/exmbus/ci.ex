defmodule Exmbus.CI do
  @moduledoc """
  MBus CI codes found in table 2 of EN-13757-7:2018
  """

  alias Exmbus.Tpl

  @table [
    # CI/CI-range, Layer module, tpl header, direction, higher layer protocol note
    {{0x00, 0x1F}, {:ok, {:apl, :none , "Reserved for DLMS-based applications", "DLMS (see EN 13757–1)"}}},
    {{0x20, 0x4F}, {:error, :reserved}},
    {0x50        , {:ok, {:apl, :none , "Application reset or select to device", "Application Selection; according to EN 13757–3:2018, Clause 7"}}},
    {0x51        , {:ok, {:apl, :none , "Command to device (full M-Bus frame)", "M-Bus (not for wireless); according to EN 13757–3:2018, Clause 6"}}},
    {0x52        , {:error, {:unhandled_ci, 0x52}}}, # Selection of device
    {0x53        , {:ok, {:apl, :long , "Application reset or select to device", "Application Selection; according to EN 13757–3:2018, Clause 7"}}},
    {0x54        , {:ok, {:apl, :none , "Request of selected application to device", "Application Selection; according to EN 13757–3:2018, Clause 7"}}},
    {0x55        , {:ok, {:apl, :long , "Request of selected application to device", "Application Selection; according to EN 13757–3:2018, Clause 7"}}},
    {{0x56, 0x59}, {:error, :reserved}},
    {0x5A        , {:ok, {:apl, :short, "Command to device (full M-Bus frame)", "M-Bus according to EN 13757–3:2018, Clause 6"}}},
    {0x5B        , {:ok, {:apl, :long , "Command to device (full M-Bus frame)", "M-Bus according to EN 13757–3:2018, Clause 6"}}},
    {0x5C        , {:ok, {:apl, :none , "Synchronize action", "according to EN 13757–3:2018, Clause 12"}}},
    {{0x5D, 0x5E}, {:error, :reserved}},
    {0x5F        , {:ok, {:tpl, :long , "Specific usage", "See Bibliographical Entry [8]"}}},
    {0x60        , {:ok, {:apl, :long , "Command to device", "DLMS/COSEM with OBIS-Identifier (according to EN 13757–1 and EN 62056–5-3)"}}},
    {0x61        , {:ok, {:apl, :short, "Command to device", "DLMS/COSEM with OBIS-Identifier (according to EN 13757–1 and EN 62056–5-3)"}}},
    {{0x62, 0x63}, {:error, :reserved}},
    {0x64        , {:ok, {:apl, :long , "Command to device", "Reserved for OBIS-type value descriptors"}}},
    {0x65        , {:ok, {:apl, :short, "Command to device", "Reserved for OBIS-type value descriptors"}}},
    {0x66        , {:ok, {:apl, :none , "Response of selected application from device", "Application Selection; according to EN 13757–3:2018, Clause 7"}}},
    {0x67        , {:ok, {:apl, :short, "Response of selected application from device", "Application Selection; according to EN 13757–3:2018, Clause 7"}}},
    {0x68        , {:ok, {:apl, :long , "Response of selected application from device", "Application Selection; according to EN 13757–3:2018, Clause 7"}}},
    {0x69        , {:ok, {:apl, :none , "Response from device (M-Bus- Format frame)", "M-Bus; according to EN 13757–3:2018, 6, Annex G"}}},
    {0x6A        , {:ok, {:apl, :short, "Response from device (M-Bus- Format frame)", "M-Bus; according to EN 13757–3:2018, Annex G"}}},
    {0x6B        , {:ok, {:apl, :long , "Response from device (M-Bus- Format frame)", "M-Bus; according to EN 13757–3:2018, Annex G"}}},
    {0x6C        , {:ok, {:apl, :long , "Time sync to device", "According to EN 13757–3:2018, Clause 8"}}},
    {0x6D        , {:ok, {:apl, :long , "Time sync to device", "According to EN 13757–3:2018, Clause 8"}}},
    {0x6E        , {:ok, {:apl, :short, "Application error from device", "According to EN 13757–3:2018, Clause 10"}}},
    {0x6F        , {:ok, {:apl, :long , "Application error from device", "According to EN 13757–3:2018, Clause 10"}}},
    {0x70        , {:ok, {:apl, :none , "Application error from device", "According to EN 13757–3:2018, Clause 10"}}},
    {0x71        , {:ok, {:apl, :none , "Alarm from device", "According to EN 13757–3:2018, Clause 9"}}},
    {0x72        , {:ok, {:apl, :long , "Response from device (full M-Bus frame)", "M-Bus; according to EN 13757–3:2018, Clause 6"}}},
    {0x73        , {:ok, {:apl, :long , "Response from device (M-Bus- Compact frame)", "M-Bus; according to EN 13757–3:2018, Clause 6, Annex G"}}},
    {0x74        , {:ok, {:apl, :short, "Alarm from device", "According to EN 13757–3:2018, Clause 9"}}},
    {0x75        , {:ok, {:apl, :long , "Alarm from device", "According to EN 13757–3:2018, Clause 9"}}},
    {{0x76, 0x77}, {:error, :reserved}},
    {0x78        , {:ok, {:apl, :none , "Response from device (full M-Bus frame)", "M-Bus; according to EN 13757–3:2018, Clause 6"}}},
    {0x79        , {:ok, {:apl, :none , "Response from device (M-Bus- Compact frame)", "M-Bus; according to EN 13757–3:2018, Clause 6, Annex G"}}},
    {0x7A        , {:ok, {:apl, :short, "Response from device (full M-Bus frame)", "M-Bus; according to EN 13757–3:2018, Clause 6"}}},
    {0x7B        , {:ok, {:apl, :short, "Response from device (M-Bus- Compact frame)", "M-Bus; according to EN 13757–3:2018, Annex G and EN 13757–3:2018, Clause 6"}}},
    {0x7C        , {:ok, {:apl, :long , "Response from device", "DLMS/COSEM with OBIS-Identifier (according to EN 13757–1 and EN 62056–5-3)"}}},
    {0x7D        , {:ok, {:apl, :short, "Response from device", "DLMS/COSEM with OBIS-Identifier (according to EN 13757–1 and EN 62056–5-3)"}}},
    {0x7E        , {:ok, {:apl, :long , "Response from device", "Reserved for OBIS-type value descriptors"}}},
    {0x7F        , {:ok, {:apl, :short, "Response from device", "Reserved for OBIS-type value descriptors"}}},
    {0x80        , {:ok, {:tpl, :long , "Transport Layer to device (without APL)", "According to EN 13757–4"}}},
    {0x81        , {:ok, {:nwl, :nil  , "Network Layer data", "According to EN 13757–5"}}},
    {0x82        , {:ok, {:apl, :long , "Network management data to device", "According to EN 13757–4 and EN 13757– 5"}}},
    {0x83        , {:ok, {:apl, :none , "Network management data to device", "According to EN 13757–4 and EN 13757– 5"}}},
    {0x84        , {:ok, {:tpl, :long , "Transport Layer to device (M- Bus-Compact frame expected)", ""}}},
    {0x85        , {:ok, {:tpl, :long , "Transport Layer to device (M- Bus-Format frame expected)", ""}}},
    {0x86        , {:ok, {:ell, :nil  , "Reserved for Extended Link Layer", "According to EN 13757–4"}}},
    {0x87        , {:ok, {:apl, :long , "Network management data from device", "According to EN 13757–4, EN 13757–5"}}},
    {0x88        , {:ok, {:apl, :short, "Network management data from device", "According to EN 13757–4, EN 13757–5"}}},
    {0x89        , {:ok, {:apl, :none , "Network management data from device", "According to EN 13757–4, EN 13757–5"}}},
    {0x8A        , {:ok, {:tpl, :short, "Transport Layer from device (without APL)", "According to EN 13757–4"}}},
    {0x8B        , {:ok, {:tpl, :long , "Transport Layer from device (without APL)", "According to EN 13757–4"}}},
    {{0x8C, 0x8F}, {:ok, {:ell, :nil  , "Extended Link Layer", "According to EN 13757–4"}}},
    {0x90        , {:ok, {:afl, :nil  , "Authentication and Fragmentation Sublayer", "According to Clause 6"}}},
    {0x91        , {:error, :reserved}},
    {{0x92, 0x97}, {:error, :reserved}},
    {{0x98, 0x9D}, {:error, :reserved}},
    {0x9E        , {:ok, {:tpl, :short, "Specific usage", "See Bibliographical Entry [8]"}}},
    {0x9F        , {:ok, {:tpl, :long , "Specific usage", "See Bibliographical Entry [8]"}}},
    {{0xA0, 0xB7}, {:ok, {:apl, :manufacturer_specific, "Manufacturer specific", "According to EN 13757–3:2018, 13"}}},
    {0xB8        , {:ok, {:apl, :none , "Set baud rate to 300 Bd", "Management of lower layers; according to 8.2"}}},
    {0xB9        , {:ok, {:apl, :none , "Set baud rate to 600 Bd", "Management of lower layers; according to 8.2"}}},
    {0xBA        , {:ok, {:apl, :none , "Set baud rate to 1 200 Bd", "Management of lower layers; according to 8.2"}}},
    {0xBB        , {:ok, {:apl, :none , "Set baud rate to 2 400 Bd", "Management of lower layers; according to 8.2"}}},
    {0xBC        , {:ok, {:apl, :none , "Set baud rate to 4 800 Bd", "Management of lower layers; according to 8.2"}}},
    {0xBD        , {:ok, {:apl, :none , "Set baud rate to 9 600 Bd", "Management of lower layers; according to 8.2"}}},
    {0xBE        , {:ok, {:apl, :none , "Set baud rate to 19 200 Bd", "Management of lower layers; according to 8.2"}}},
    {0xBF        , {:ok, {:apl, :none , "Set baud rate to 38 400 Bd", "Management of lower layers; according to 8.2"}}},
    {0xC0        , {:ok, {:apl, :long , "Command to device", "Image transfer; according to EN 13757– 3:2018, Annex I,"}}},
    {0xC1        , {:ok, {:apl, :short, "Response from device", "Image transfer; according EN 13757– 3:2018, Annex I"}}},
    {0xC2        , {:ok, {:apl, :long , "Response from device", "Image transfer; according to EN 13757– 3:2018, Annex I"}}},
    {0xC3        , {:ok, {:apl, :long , "Command to device", "Security Information Transfer; according to Annex A"}}},
    {0xC4        , {:ok, {:apl, :short, "Response from device", "Security Information Transfer; according to Annex A"}}},
    {0xC5        , {:ok, {:apl, :long , "Response from device", "Security Information Transfer; according to Annex A"}}},
    {{0xC6, 0xFF}, {:error, :reserved}},
  ]

  @doc """
  Decode based on the next CI byte, but passing the full binary
  to the responsible decode function, effectivly making this function pure routing based on CI.
  """
  @spec decode(binary()) :: {:ok, term(), rest :: binary()} | {:error, reason :: any()}
  def decode(<<ci, _::binary>>=bin) do
    case lookup(ci) do
      # If APL then TPL is also implied because EN 13757-7:2018 section 5.2:
      # > The Transport Layer and the Application Layer uses a shared CI-field.
      # > For that reason, a Transport Layer shall be present whenever the Application Layer is used in a message.
      {:ok, {:tpl, _tpl_header, _, _}} ->
        Tpl.decode(bin)
      {:ok, {:apl, _tpl_header, _, _}} ->
        Tpl.decode(bin)
      # TODO rest here

      # lookup error:
      e ->
        e
    end
  end

  # as per the table 2 in the mbus docs
  def layer(ci), do: lookup_element(ci, 0)
  def tpl_type(ci), do: lookup_element(ci, 1)
  def direction(ci), do: lookup_element(ci, 2)
  def higher_layer_protocol(ci), do: lookup_element(ci, 4)

  defp lookup_element(ci, n) do
    case lookup(ci) do
      {:ok, t} -> elem(t, n)
      e        -> e
    end
  end

  # define lookup function based on above table.
  Enum.each(@table, fn ({ci, entry}) ->
    case ci do
      {lower, upper} ->
        def lookup(n) when n >= unquote(lower) and n <= unquote(upper), do: unquote(Macro.escape(entry))
      ci ->
        def lookup((unquote(ci))), do: unquote(Macro.escape(entry))
    end
  end)
  def lookup(ci), do: {:error, {:unknown_ci, ci}}
end
