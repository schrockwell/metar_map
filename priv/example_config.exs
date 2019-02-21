#
# This config file belongs at:
#
#     /etc/metar-map/config.exs
#
# Modify the values below for your particular build.
#
use Mix.Config

# The total number of WS281x LEDs in the string
led_count = 100

# The GPIO pin for WS281x LED data control.
# To see available pins, read: https://github.com/jgarff/rpi_ws281x#gpio-usage
led_pin = 18

# If the light sensor (LDR) is connected, use this GPIO pin.
# Set to false if no light sensor is connected.
ldr_pin = 1

# The stations are an array of tuples containing the full airport identifier and the LED
# index (zero-based).
stations = [
  {"KHFD", 1},
  {"KBDL", 2},
  {"KHYA", 3},
  {"KMWN", 4}
]

# --- No need to change anything below ---

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
  stations: stations
