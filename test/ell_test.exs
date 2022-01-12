defmodule EllTest do
  use ExUnit.Case
  alias Exmbus.Ell

  doctest Exmbus.Ell, import: true

  # Test a frame with ELL but without encryption, like
  # 44372c420119233a168d20c2c201aa00ba867804ff23000000004413d0650000523bd60206ff1b043000033000426cc12161670e516719023b00000413ce6600008101e7ff0f0c

  # Test a frame with ELL and aes_128_ctr encryption
  # Test a frame with ELL and aes_128_ctr encryption trying multiple keys
  # Test a frame with ELL and aes_128_ctr encryption trying multiple keys, no valid

  # test a frame with bad CRC

  # etc, Just look in ell.ex


end
