# Raspberry Pi Setup

## Versions

* Model: Raspberry Pi Model 3 B+
* Pi OS: [Raspbian Stretch Lite](https://www.raspberrypi.org/downloads/raspbian/)
* Desktop OS: macOS 10.14 Mojave
* Elixir: 1.7.4
* Erlang/OTP: 20

## Directions

Download and unzip Raspbian.

```
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

```
diskutil eject /dev/disk2
```

Log into the pi as user `pi` with password `raspberry`. Do everything below as `root`

```
# We're rooting for you!
sudo bash

# Set up Elixir/Erlang repos for apt
echo "deb https://packages.erlang-solutions.com/debian stretch contrib" | sudo tee /etc/apt/sources.list.d/erlang-solutions.list
wget https://packages.erlang-solutions.com/debian/erlang_solutions.asc
apt-key add erlang_solutions.asc

# Install required things
apt update
apt upgrade -y
apt install git python3-gpiozero vim elixir -y

# Get the repo (still as root)
cd /root

mix local.hex --force
mix local.rebar --force

export PORT=80
export MIX_ENV=prod
export CROSSCOMPILE=1 # Hack for Blinkchain

git clone https://github.com/schrockwell/metar_map.git
cd metar_map
mix deps.get
mix compile
mix phx.digest

# Run it!
mix phx.server
```

Now set up the config files:

```
# Set up systemd
cp priv/metar-map.service /etc/systemd/system/metar-map.service

# Set up static application config (stations, etc.)
mkdir -p /etc/metar-map
cp priv/example_config.exs /etc/metar-map/config
vim /etc/metar-map/config # And edit away!

# Launch it!
systemctl enable metar-map
systemctl start metar-map
systemctl status metar-map
```

Look for it running on port 80.

## Helpful Stuff

Use `pinout` to see the Raspberry Pi pinout! Whoa!

