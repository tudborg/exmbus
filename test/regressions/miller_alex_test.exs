defmodule Regressions.MillerAlexTest do
  use ExUnit.Case, async: true

  # used to cause: (RuntimeError) E001 0011 Inverse Compact Profile not supported
  test "wmbus, encrypted" do
    key = Base.decode16!("F8B24F12F9D113F680BEE765FDE67EC0")

    datagram =
      Base.decode16!(
        "6644496A3100015514377203926314496A00075000500598A78E0D71AA6358EEBD0B20BFDF99EDA2D22FA25314F3F1B84470898E495303923770BA8DDA97C964F0EA6CE24F5650C0A6CDF3DE37DE33FBFBEBACE4009BB0D8EBA2CBE80433FF131328206020B1BF"
      )

    assert {:ok, ctx} = Exmbus.parse(datagram, length: true, crc: false, key: key)

    assert %Exmbus.Parser.Context{
             apl: %Exmbus.Parser.Apl.FullFrame{
               manufacturer_bytes: "",
               records: [
                 %Exmbus.Parser.Apl.DataRecord{
                   data: 67329,
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       multiplier: 0.001,
                       unit: "m^3",
                       description: :volume
                     },
                     coding: :type_a,
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       tariff: 0,
                       storage: 0
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: ~D[2020-01-20],
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       tariff: 0,
                       storage: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :date
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: ~D[2020-01-01],
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 8,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :date
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: 64475,
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     coding: :type_a,
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 8,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :volume,
                       multiplier: 0.001,
                       unit: "m^3"
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: ~D[2019-12-01],
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 9,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :date
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: 60063,
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     coding: :type_a,
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 9,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :volume,
                       multiplier: 0.001,
                       unit: "m^3"
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: ~D[2019-11-01],
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 10,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :date
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: 55912,
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     coding: :type_a,
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 10,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :volume,
                       multiplier: 0.001,
                       unit: "m^3"
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: ~D[2019-10-01],
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 11,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :date
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: 52342,
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     coding: :type_a,
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 11,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :volume,
                       multiplier: 0.001,
                       unit: "m^3"
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: ~D[2019-09-01],
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 12,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :date
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: 48965,
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     coding: :type_a,
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 12,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :volume,
                       multiplier: 0.001,
                       unit: "m^3"
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: ~D[2019-08-01],
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 13,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :date
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: 43990,
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     coding: :type_a,
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 13,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :volume,
                       multiplier: 0.001,
                       unit: "m^3"
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: ~D[2019-07-01],
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 14,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :date
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: 40374,
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     coding: :type_a,
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 14,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :volume,
                       multiplier: 0.001,
                       unit: "m^3"
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: ~D[2019-06-01],
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 15,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :date
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: 34701,
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     coding: :type_a,
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 15,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :volume,
                       multiplier: 0.001,
                       unit: "m^3"
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: ~D[2019-05-01],
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 16,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :date
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: 29110,
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     coding: :type_a,
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 16,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :volume,
                       multiplier: 0.001,
                       unit: "m^3"
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: ~D[2019-04-01],
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 17,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :date
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: 23315,
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     coding: :type_a,
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 17,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :volume,
                       multiplier: 0.001,
                       unit: "m^3"
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: ~D[2019-03-01],
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 18,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :date
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: 17584,
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     coding: :type_a,
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 18,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :volume,
                       multiplier: 0.001,
                       unit: "m^3"
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: ~D[2019-02-01],
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 19,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :date
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: 13356,
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     coding: :type_a,
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 19,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :volume,
                       multiplier: 0.001,
                       unit: "m^3"
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: ~D[2019-01-01],
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 20,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :date
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: 8638,
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     coding: :type_a,
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 20,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :volume,
                       multiplier: 0.001,
                       unit: "m^3"
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: ~D[2018-12-01],
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 21,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :date
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: 4677,
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     coding: :type_a,
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 21,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :volume,
                       multiplier: 0.001,
                       unit: "m^3"
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: ~D[2018-11-01],
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 22,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :date
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: 421,
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     coding: :type_a,
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 22,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       description: :volume,
                       multiplier: 0.001,
                       unit: "m^3"
                     }
                   }
                 },
                 %Exmbus.Parser.Apl.DataRecord{
                   data: [
                     false,
                     false,
                     false,
                     false,
                     false,
                     false,
                     false,
                     false,
                     false,
                     false,
                     false,
                     false,
                     false,
                     false,
                     false,
                     false
                   ],
                   header: %Exmbus.Parser.Apl.DataRecord.Header{
                     coding: :type_d,
                     dib: %Exmbus.Parser.Apl.DataRecord.DataInformationBlock{
                       device: 0,
                       storage: 0,
                       tariff: 0
                     },
                     vib: %Exmbus.Parser.Apl.DataRecord.ValueInformationBlock{
                       coding: :type_d,
                       description: :error_flags,
                       table: :fd
                     }
                   }
                 }
               ]
             },
             dll: %Exmbus.Parser.Dll.Wmbus{
               control: :snd_nr,
               device: :radio_converter_meter_side,
               identification_no: 55_010_031,
               manufacturer: "ZRI",
               version: 20
             },
             tpl: %Exmbus.Parser.Tpl{
               frame_type: :full_frame,
               header: %Exmbus.Parser.Tpl.Header.Long{
                 access_no: 80,
                 configuration_field: %Exmbus.Parser.Tpl.ConfigurationField{
                   accessibility: false,
                   bidirectional: false,
                   blocks: 5,
                   content_of_message: 0,
                   hop_count: 0,
                   mode: 5,
                   repeater_access: 0,
                   syncrony: false
                 },
                 device: :water,
                 identification_no: 14_639_203,
                 manufacturer: "ZRI",
                 status: %Exmbus.Parser.Tpl.Status{
                   application_status: :no_error,
                   low_power: false,
                   manufacturer_status: 0,
                   permanent_error: false,
                   temporary_error: false
                 },
                 version: 0
               }
             },
             errors: []
           } = ctx
  end

  # Used to cause:
  # ** (FunctionClauseError) no function clause matching in Exmbus.Parser.Apl.DataRecord.ValueInformationBlock.Vife.exts/4
  # NOTE: this frame is from a Lansen sensor, probably something like a CMa11.
  # It uses plain-text VIFs that are clearly incorrect according to the standard, so this frame is "invalid".
  # The problem is that header of the records are DIF, VIF, ASCII unit, VIFE, which is incorrect according to EN 13757-3:2018.
  # There is a counter example in section C.2, where the order with a VIFE is clearly defined.
  # However I suspect that this example has been added because the wording around where to place the ascii units is a bit unclear.
  # But logically, since the VIFE is a modifier to the VIF and always delimited by the extension bits, those should come first,
  # and the length-prefixed ASCII unit should come last, as the final part of the VIB.
  # (But in some mbus docs I could fine, it is said that the VIFE with extension bit 0 closes the VIB, so I totally get why someone would place the ASCII unit before it)
  @tag :skip
  test "mbus" do
    datagram =
      Base.decode16!(
        "684D4D680801720100000096150100180000000C785600000001FD1B0002FC0348522574440D22FC0348522574F10C12FC034852257463110265B409226586091265B70901720072650000B2016500001FB316"
      )

    assert {:ok, _ctx, <<>>} = Exmbus.parse(datagram, length: true, crc: false)
  end
end
