defmodule CompactFrameTest do
  use ExUnit.Case, async: true

  alias Exmbus.Parser.Apl.DataRecord
  alias Exmbus.Parser.Context
  alias Exmbus.Parser.Tpl
  alias Exmbus.Parser.Apl.FullFrame
  alias Exmbus.Parser.Apl.CompactFrame
  alias Exmbus.Parser.Apl.FormatFrame

  doctest Exmbus.Parser.Apl.CompactFrame, import: true

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

      handlers = [&Exmbus.Parser.Tpl.parse/1, &Exmbus.Parser.Apl.parse/1]

      # assert that the parsed full frame contains what the docs says it contains
      assert {:ok,
              %{
                apl: %FullFrame{} = full_frame,
                tpl: %Tpl{frame_type: :full_frame, header: %Tpl.Header.None{}}
              }} = Exmbus.parse(bytes_full, Context.new(handlers: handlers))

      assert records:
               [
                 %{description: :energy, value: 123.4, unit: "Wh"},
                 %{description: :volume, value: 567.8000000000001, unit: "m^3"},
                 %{description: :power, value: 901.2, unit: "W"}
               ] = Enum.map(full_frame.records, &DataRecord.to_map!/1)

      assert {:ok, 15153} == FullFrame.format_signature(full_frame)

      # assert that the parsed format frame results in the same signature
      assert {:ok,
              %{
                apl: %FormatFrame{} = format_frame,
                tpl: %Tpl{frame_type: :format_frame, header: %Tpl.Header.None{}}
              }} = Exmbus.parse(bytes_format, Context.new(handlers: handlers))

      assert {:ok, 15153} == FormatFrame.format_signature(format_frame)

      assert format_frame.headers == Enum.map(full_frame.records, & &1.header)

      # assert that the compact frame produces the same values as the full frame
      # given the format frame

      assert {:ok,
              %{
                apl: %CompactFrame{format_signature: 15153},
                tpl: %Tpl{frame_type: :compact_frame, header: %Tpl.Header.None{}}
              } = compact_frame_ctx} =
               Exmbus.parse(bytes_compact, Context.new(handlers: handlers))

      ffl = fn 15153, _opts ->
        {:ok, format_frame}
      end

      assert {:continue, %{apl: %FullFrame{} = full_frame_from_compact, tpl: %Tpl{}}} =
               compact_frame_ctx
               |> Context.merge(opts: [format_frame_fn: ffl])
               |> CompactFrame.expand()

      assert full_frame == full_frame_from_compact
    end

    test "G.5.3 Example with short data header, no encryption" do
      bytes_full = "7A010000000202D20402152E16022A3423" |> Base.decode16!()
      bytes_format = "6A0100000008313B02020215022A" |> Base.decode16!()
      bytes_compact = "7B01000000313B42A6D2042E163423" |> Base.decode16!()

      # only parse TPL and APL
      handlers = [&Exmbus.Parser.Tpl.parse/1, &Exmbus.Parser.Apl.parse/1]

      assert {:ok, %{apl: %FullFrame{} = _full_frame}} =
               Exmbus.parse(bytes_full, Context.new(handlers: handlers))

      assert {:ok, %{apl: %FormatFrame{} = format_frame}} =
               Exmbus.parse(bytes_format, Context.new(handlers: handlers))

      assert {:ok, %{apl: %CompactFrame{} = _compact_frame} = compact_frame_ctx} =
               Exmbus.parse(bytes_compact, Context.new(handlers: handlers))

      # add a format_frame_fn to lookup format frames.
      # this one just hardcodes the format frame to the one we have parsed
      # which is the frame we expect to expand on
      compact_frame_ctx =
        compact_frame_ctx
        |> Context.merge(opts: [format_frame_fn: fn _, _ -> {:ok, format_frame} end])

      assert {:continue, %{apl: %FullFrame{} = _full_frame_from_compact}} =
               CompactFrame.expand(compact_frame_ctx)
    end
  end

  describe "regressions" do
    # The initial problem with the following is that the expanding the compact frame yields a
    # different full frame CRC than what the compact frame expected.
    # The problem turned out to be a bug in the unparse functions, causing the Full-Frame-CRC to not match
    test "Full frame CRC problem 2022-01-14" do
      handlers = [&Exmbus.Parser.Tpl.parse/1, &Exmbus.Parser.Apl.parse/1]

      bytes_full = "780306EB24004306E723000314285E00426CBF2C022D030001FF2100" |> Base.decode16!()
      bytes_compact = "79E7F1A3FCED2400E723002E5E00BF2C0D0000" |> Base.decode16!()
      # parse the frames
      assert {:ok, %{apl: %FullFrame{} = full_frame}} =
               Exmbus.parse(bytes_full, Context.new(handlers: handlers))

      assert {:ok, %{apl: %CompactFrame{} = compact_frame}} =
               Exmbus.parse(bytes_compact, Context.new(handlers: handlers))

      # derive the format frame from the full
      assert %FormatFrame{} = format_frame = FormatFrame.from_full_frame!(full_frame)
      # check that the format signature of the derived format frame
      # and the requested format signature from the compact frame matches:
      assert FormatFrame.format_signature(format_frame) == {:ok, compact_frame.format_signature}

      # the lookup function to fund the format frame is then just a function tht returns the format frame:
      format_frame_fn = fn _fs, _opts -> {:ok, format_frame} end
      # expand the compact frame which should succeed:
      assert {:continue, _expanded_layers} =
               Context.new(apl: compact_frame, opts: [format_frame_fn: format_frame_fn])
               |> CompactFrame.expand()
    end
  end
end
