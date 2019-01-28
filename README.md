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

# GTFO
diskutil eject /dev/disk2
```

Log into the pi as user `pi` with password `raspberry`.

```
sudo bash

# Set up Elixir repos
echo "deb https://packages.erlang-solutions.com/debian stretch contrib" | sudo tee /etc/apt/sources.list.d/erlang-solutions.list
wget https://packages.erlang-solutions.com/debian/erlang_solutions.asc
apt-key add erlang_solutions.asc

# Install required things
apt update
apt upgrade -y
apt install git python3-gpiozero vim elixir -y

mix local.hex --force
mix local.rebar --force

# Get the repo
git clone https://github.com/schrockwell/metar_map.git
cd metar_map
mix deps.get
CROSSCOMPILE=1 mix compile # Hack for Blinkchain
```

## Helpful Stuff

Use `pinout` to see the Raspberry Pi pinout! Whoa!

