defmodule CompactFrameTest do
  use ExUnit.Case

  alias Exmbus.Tpl
  alias Exmbus.Apl
  alias Exmbus.Apl.FullFrame
  alias Exmbus.Apl.CompactFrame
  alias Exmbus.Apl.FormatFrame

  describe "EN 13757-3:2018(EN) - G.5" do
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
        } = CompactFrame.expand(%{format_frame_lookup: ffl}, compact_frame_ctx)

      assert full_frame == full_frame_from_compact
    end
  end

end
