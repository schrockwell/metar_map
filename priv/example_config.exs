use Mix.Config

led_count = 100
led_pin = 18
ldr_pin = false

config :blinkchain, canvas: {led_count, 1}

config :blinkchain, :channel0,
  pin: led_pin,
  type: :rgb,
  arrangement: [
    %{
      type: :strip,
      origin: {0, 0},
      count: led_count,
      direction: :right
    }
  ]

config :metar_map,
  ldr_pin: ldr_pin,
  stations: [
    {"KHFD", 1},
    {"KBDL", 2},
    {"KHYA", 3},
    {"KMWN", 4}
  ]
