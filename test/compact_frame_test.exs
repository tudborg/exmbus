defmodule CompactFrameTest do
  use ExUnit.Case, async: true

  alias Exmbus.Tpl
  alias Exmbus.Apl
  alias Exmbus.Apl.FullFrame
  alias Exmbus.Apl.CompactFrame
  alias Exmbus.Apl.FormatFrame

  doctest Exmbus.Apl.CompactFrame, import: true

  describe "EN 13757-3:2018(EN) - G.5:" do
    # The following examples contain the dataset:
    # - Energy = 123,4 Wh
    # - Volume = 567,8 m^3
    # - Power = 901,2 W

    test "Format frame signature from old parser" do
      dif_and_vif_bytes = "040404843C042B04AB3C" |> Base.decode16!()
      {:ok, 35859} = FormatFrame.format_signature(dif_and_vif_bytes)
    end

    test "Format frame signature" do
      dif_and_vif_bytes = <<0x02, 0x02, 0x02, 0x15, 0x02, 0x2A>>
      {:ok, 15153} = FormatFrame.format_signature(dif_and_vif_bytes)
    end

    test "G.5.2 Example without data header" do
      bytes_full = "780202D20402152E16022A3423" |> Base.decode16!()
      bytes_format = "6908313B02020215022A" |> Base.decode16!()
      bytes_compact = "79313B42A6D2042E163423" |> Base.decode16!()

      # assert that the parsed full frame contains what the docs says it contains
      assert {:ok, [
          %FullFrame{}=full_frame,
          %Tpl{frame_type: :full_frame, header: %Tpl.None{}},
        ], <<>>} = Tpl.parse(bytes_full, %{}, [])

      assert %{records: [
          %{description: :energy, value: 123.4, unit: "Wh"},
          %{description: :volume, value: 567.8000000000001, unit: "m^3"},
          %{description: :power, value: 901.2, unit: "W"},
        ]} = Apl.to_map!(full_frame)

      assert {:ok, 15153} == FullFrame.format_signature(full_frame)

      # assert that the parsed format frame results in the same signature
      assert {:ok, [
        %FormatFrame{}=format_frame,
        %Tpl{frame_type: :format_frame, header: %Tpl.None{}},
      ], <<>>} = Tpl.parse(bytes_format, %{}, [])

      assert {:ok, 15153} == FormatFrame.format_signature(format_frame)

      assert format_frame.headers == Enum.map(full_frame.records, &(&1.header))

      # assert that the compact frame produces the same values as the full frame
      # given the format frame

      assert {:ok, [
          %CompactFrame{format_signature: 15153},
          %Tpl{frame_type: :compact_frame, header: %Tpl.None{}},
        ]=compact_frame_ctx, <<>>} = Tpl.parse(bytes_compact, %{}, [])

      ffl = fn (15153, _opts) ->
        {:ok, format_frame}
      end
      assert {:ok,
        [%FullFrame{}=full_frame_from_compact, %Tpl{}]
        } = CompactFrame.expand(%{format_frame_fn: ffl}, compact_frame_ctx)

      assert full_frame == full_frame_from_compact
    end

    test "G.5.3 Example with short data header, no encryption" do
      bytes_full = "7A010000000202D20402152E16022A3423" |> Base.decode16!()
      bytes_format = "6A0100000008313B02020215022A" |> Base.decode16!()
      bytes_compact = "7B01000000313B42A6D2042E163423" |> Base.decode16!()

      assert {:ok, [%FullFrame{}=full_frame | _], <<>>} = Tpl.parse(bytes_full, %{}, [])
      assert {:ok, [%FormatFrame{}=format_frame | _], <<>>} = Tpl.parse(bytes_format, %{}, [])
      assert {:ok, [%CompactFrame{}=compact_frame | _]=compact_frame_ctx, <<>>} = Tpl.parse(bytes_compact, %{}, [])

      format_frame_fn = fn (_, _) -> {:ok, format_frame} end

      assert {:ok, [%FullFrame{}=full_frame_from_compact | _]} = CompactFrame.expand(%{format_frame_fn: format_frame_fn}, compact_frame_ctx)
    end
  end

  describe "regressions" do
    # The initial problem with the following is that the expanding the compact frame yields a
    # different full frame CRC than what the compact frame expected.
    # The problem turned out to be a bug in the unparse functions, causing the Full-Frame-CRC to not match
    test "Full frame CRC problem 2022-01-14" do
      bytes_full = "780306EB24004306E723000314285E00426CBF2C022D030001FF2100" |> Base.decode16!()
      bytes_compact = "79E7F1A3FCED2400E723002E5E00BF2C0D0000" |> Base.decode16!()
      # parse the frames
      assert {:ok, [%FullFrame{}=full_frame | _], ""} = Tpl.parse(bytes_full, %{}, [])
      assert {:ok, [%CompactFrame{}=compact_frame | _], ""}= Tpl.parse(bytes_compact, %{}, [])
      # derive the format frame from the full
      assert %FormatFrame{} = format_frame = FormatFrame.from_full_frame!(full_frame)
      # check that the format signature of the derived format frame
      # and the requested format signature from the compact frame matches:
      assert FormatFrame.format_signature(format_frame) == {:ok, compact_frame.format_signature}
      # the lookup function to fund the format frame is then just a function tht returns the format frame:
      format_frame_fn = fn _fs, _opts -> {:ok, format_frame} end
      # expand the compact frame which should succeed:
      assert {:ok, expanded_layers} = CompactFrame.expand(%{format_frame_fn: format_frame_fn}, [compact_frame])
    end
  end

end
