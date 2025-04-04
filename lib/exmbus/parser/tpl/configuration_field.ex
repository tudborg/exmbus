defmodule Exmbus.Parser.Tpl.ConfigurationField do
  defstruct hop_count: 0,
            repeater_access: 0,
            content_of_message: 0,
            mode: 0,
            syncrony: false,
            accessibility: false,
            bidirectional: false,
            blocks: nil

  @type t :: %__MODULE__{
          hop_count: 0..1,
          repeater_access: 0..1,
          content_of_message: 0..3,
          mode: 0..31,
          syncrony: boolean(),
          accessibility: boolean(),
          bidirectional: boolean(),
          blocks: nil | 0..15
        }

  @spec decode(binary()) :: {:ok, t()}
  def decode(<<a, b>>) do
    # we flip the bits so they are MSB,LSB. Easier to read.
    # we could collapse this but performance benefit is effectively 0.
    be_decode(<<b, a>>)
  end

  # common bit names:
  # - H     :: Hop Count            Used in repeated messages.
  # - R     :: Repeater Access      Used in repeated messages.
  #                                 A meter shall always set H = 0b and R = 0b in a transmitted message
  #
  #                                 Table 21 — Content of meter message:
  # - CC    :: Content of Message   00=standard, 01=reserved, 10=static, 11=reserved for extensions
  #                                 The subfield CC shall only be applied for message types SND-NR and SND-IR
  #                                 Table 22 — Content of partner message:
  #                                 00=standard command, 01=reserved, 10=reserved, 11=reserved for ext
  #                                 The subfield CC shall only be applied for message types SND-UD, SND-UD2 or SND-UD3
  #
  # - IIII  :: Content Index        This field is used to differentiate between meter messages with different content but with the same content field value ‘CC’
  #                                 Using this field a receiver is able to identify and store or filter messages with different content without the need to decrypt the application data.
  # - MMMMM :: Mode

  # - S     :: Syncrony bit         Used to declare a synchronous transmission.
  #                                 See synchronous transmission as defined in EN 13757-4

  #                                 A and B is used in combination:
  # - A     :: Accessibility bit    BA=00 Meter/actuator provides no access window (unidirectional meter)
  # - B     :: Bidirectional bit    BA=01 Meter supports bidirectional access in general, but there is no access window after this transmission
  #                                 BA=10 Meter provides a short access window only immediately after this transmission
  #                                 BA=11 Meter provides unlimited access (at least until the next transmission)
  #                                 These bits are reserved for the wireless M-Bus communication.
  #                                 For the communication on wired M-Bus, the bits B, A and S shall be set to “0”.
  # - KKKK  :: Key ID               The Key ID (KKKK) is used to identify the applied key for this message
  # - V     :: Version              The Version bit (V) enables the Key Version field. The Key Version field is only present in TPL-Header (see 7.7.5 to 7.7.8)
  # - DD    :: KDF-Selection        Key Derivation Function, if any:
  #                                 DD=00 Persistent Key, no key derivation
  #                                 DD=01 Key Derivation Function A (see 9.6.1)
  #                                 DD=10 and DD=11 are reserved
  # security Mode 0
  defp be_decode(<<b::1, a::1, s::1, 0::5, _res::4, cc::2, r::1, h::1>>) do
    cf = %__MODULE__{
      hop_count: h,
      repeater_access: r,
      content_of_message: cc,
      syncrony: s == 1,
      accessibility: a == 1,
      bidirectional: b == 1,
      mode: 0,
      blocks: nil
    }

    {:ok, cf}
  end

  # Security Mode 5. AES-128 CBC (9.4.4 for details)
  defp be_decode(<<b::1, a::1, s::1, 5::5, blocks::4, cc::2, r::1, h::1>>) do
    cf = %__MODULE__{
      hop_count: h,
      repeater_access: r,
      content_of_message: cc,
      syncrony: s == 1,
      accessibility: a == 1,
      bidirectional: b == 1,
      mode: 5,
      blocks: blocks
    }

    {:ok, cf}
  end

  # raise if unknown encryption mode
  defp be_decode(<<_::3, mode::5, _::8>> = cfbin) do
    raise "Encryption mode #{mode} not implemented. configuration field bits were #{Exmbus.Debug.to_bits(cfbin)}"
  end
end
