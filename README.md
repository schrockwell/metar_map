# Raspberry Pi Setup

## Versions

* Raspberry Pis: 3 B+, Zero
* Pi OS: [Raspbian Stretch Lite](https://www.raspberrypi.org/downloads/raspbian/)
* Desktop OS: macOS 10.14 Mojave
* Elixir: 1.7.4
* Erlang/OTP: 20

## Directions

### Install Raspbian (macOS)

Download and unzip Raspbian.

```bash
# Get SD card device, e.g. /dev/disk2, then unmount it
diskutil list
diskutil unmountDisk /dev/disk2

# Install the image
unzip ~/Downloads/2018-11-13-raspbian-stretch-lite.zip
sudo dd bs=1m if=~/Downloads/2018-11-13-raspbian-stretch-lite.img of=/dev/rdisk2

# Enable SSH on Pi boot
touch /Volumes/boot/ssh
```

To configure Wi-Fi, edit `wpa_supplicant.conf` which is also in the SD root.

```
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="MY_SSID"
    psk="MY_PASSWORD"
    key_mgmt=WPA-PSK
}
```

Now eject the SD card.

```bash
diskutil eject /dev/disk2
```

### Install Project

Log into the pi as user `pi` with password `raspberry`. Do everything below as `root`

```bash
# We're rooting for you!
sudo bash

# Change the hostname
vim /etc/hostname
vim /etc/hosts
reboot 
```

Then log back in.

```bash
# Set up Elixir/Erlang repos for apt
echo "deb https://packages.erlang-solutions.com/debian stretch contrib" | sudo tee /etc/apt/sources.list.d/erlang-solutions.list
wget https://packages.erlang-solutions.com/debian/erlang_solutions.asc
apt-key add erlang_solutions.asc

# Install required things
apt update
apt upgrade -y
apt install git python3-gpiozero vim elixir erlang-dev erlang-parsetools erlang-xmerl -y

# Get the repo (still as root)
cd /root
git clone https://github.com/schrockwell/metar_map.git
cd metar_map

# Set up static application config - see below in README
mkdir -p /etc/metar-map
cp priv/example_config.exs /etc/metar-map/config.exs
vim /etc/metar-map/config # And edit away!

# Do the initial compilation
export MIX_ENV=prod CROSSCOMPILE=1 # Hack for Blinkchain

mix local.rebar --force
mix local.hex --force
mix compile # This will take a while

# Set up systemd service
cp priv/metar-map.service /etc/systemd/system/metar-map.service

# Launch it!
systemctl enable metar-map
systemctl start metar-map
systemctl status metar-map
```

Look for it running on port 80.

## Example Config File

As part of the steps above, you'll copy a config file to `/etc/metar-map/config.exs`. Here's what
that looks like.

```elixir
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
```

## On-Device Development

```bash
export MIX_ENV=prod CROSSCOMPILE=1 # Hack for Blinkchain

cd /root/metar_map
mix deps.get
mix compile
mix phx.digest
mix phx.server
```

## Helpful Stuff

Use `pinout` to see the Raspberry Pi pinout! Whoa!

