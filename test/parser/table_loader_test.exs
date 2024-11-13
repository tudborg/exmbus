defmodule Parser.TableLoaderTest do
  use ExUnit.Case, async: true

  alias Exmbus.Parser.TableLoader

  test "from_file!/1" do
    path = Application.app_dir(:exmbus, "priv/ci.csv")
    assert [_ | _] = TableLoader.from_file!(path)
    path = Application.app_dir(:exmbus, "priv/device.csv")
    assert [_ | _] = TableLoader.from_file!(path)
  end
end
