use Mix.Config

config :blinkchain, :channel0,
  pin: 18,
  type: :rgb,
  arrangement: [
    %{
      type: :strip,
      origin: {0, 0},
      count: 100,
      direction: :right
    }
  ]

config :metar_map,
  ldr_pin: false,
  stations: [
    {"KHFD", 1},
    {"KBDL", 2},
    {"KHYA", 3},
    {"KMWN", 4}
  ]
