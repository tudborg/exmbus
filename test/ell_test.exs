defmodule EllTest do
  use ExUnit.Case, async: true
  doctest Exmbus.Parser.Ell, import: true

  # Test a frame with ELL but without encryption, like

  # Test a frame with ELL and aes_128_ctr encryption
  # Test a frame with ELL and aes_128_ctr encryption trying multiple keys
  # Test a frame with ELL and aes_128_ctr encryption trying multiple keys, no valid

  # test a frame with bad CRC

  # etc, Just look in ell.ex
end
