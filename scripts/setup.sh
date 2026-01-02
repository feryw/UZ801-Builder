#!/bin/sh -e

DEBIAN_FRONTEND=noninteractive
DEBCONF_NONINTERACTIVE_SEEN=true

echo 'tzdata tzdata/Areas select Asia' | debconf-set-selections
echo 'tzdata tzdata/Zones/Asia select Jakarta' | debconf-set-selections
dpkg-reconfigure -f noninteractive tzdata
echo "locales locales/default_environment_locale select en_US.UTF-8" | debconf-set-selections
echo "locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8" | debconf-set-selections
rm -f "/etc/locale.gen"

apt update -qqy
apt upgrade -qqy
apt autoremove -qqy
apt install -qqy --no-install-recommends \
    bridge-utils \
    dnsmasq \
    hostapd \
    iptables \
    libconfig9 \
    htop \
    bash \
    nano \
    neofetch \
    iftop \
    locales \
    modemmanager \
    netcat-traditional \
    net-tools \
    network-manager \
    openssh-server \
    qrtr-tools \
    rmtfs \
    sudo \
    systemd-timesyncd \
    tzdata \
    wireguard-tools \
    wpasupplicant

apt clean
rm -rf /var/lib/apt/lists/*

passwd -d root

echo wyref:1::::/home/wyref:/bin/bash | newusers
echo 'wyref ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/wyref
