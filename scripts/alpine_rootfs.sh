#!/bin/sh

set -eu

INPUT_RELEASE="${RELEASE_INPUT:?RELEASE_INPUT not set}"
TYPEDEV="${DEV_TYPE:?DEV_TYPE not set}"

CHROOT="${CHROOT:-$(pwd)/rootfs}"
HOST_NAME="${HOST_NAME:-$TYPEDEV-alpine}"
export CHROOT HOST_NAME

rm -rf ${CHROOT}
mkdir -p ${CHROOT}/etc/apk

case "$INPUT_RELEASE" in
  v25.12)
    RELEASE="v3.23"
    PMOS_RELEASE="v25.12"
    APK_VER="v3.0.3"
    ;;
  v25.06)
    RELEASE="v3.22"
    PMOS_RELEASE="v25.06"
    APK_VER="v2.14.9"
    ;;
  v24.12)
    RELEASE="v3.21"
    PMOS_RELEASE="v24.12"
    APK_VER="v2.14.6"
    ;;
  v24.06)
    RELEASE="v3.20"
    PMOS_RELEASE="v24.06"
    APK_VER="v2.14.4"
    ;;
  *)
    echo "Unsupported release: $INPUT_RELEASE" >&2
    exit 1
    ;;
esac

export RELEASE
export PMOS_RELEASE
export MIRROR=${MIRROR=http://dl-cdn.alpinelinux.org/alpine}
export PMOS_MIRROR=${PMOS_MIRROR=http://mirror.postmarketos.org/postmarketos}

cat << EOF >  ${CHROOT}/etc/apk/repositories
${MIRROR}/${RELEASE}/main
${MIRROR}/${RELEASE}/community
${PMOS_MIRROR}/${PMOS_RELEASE}
EOF

cp /etc/resolv.conf ${CHROOT}/etc/

mkdir -p ${CHROOT}/usr/bin
cp $(which qemu-armhf-static) ${CHROOT}/usr/bin

wget "https://gitlab.alpinelinux.org/api/v4/projects/5/packages/generic/${APK_VER}/x86_64/apk.static"
chmod a+x apk.static
./apk.static add -p ${CHROOT} --initdb -U --arch armv7 --allow-untrusted alpine-base
rm apk.static

# install apps
chroot ${CHROOT} ash -l -c "
apk add --no-cache --allow-untrusted postmarketos-keys
apk add --no-cache \
    bridge-utils \
    chrony \
    dropbear \
    eudev \
    gadget-tool \
    iptables \
    linux-postmarketos-qcom-msm8916 \
    modemmanager \
    msm-firmware-loader \
    networkmanager-cli \
    networkmanager-dnsmasq \
    networkmanager-tui \
    networkmanager-wifi \
    networkmanager-wwan \
    openrc \
    rmtfs \
    sudo \
    udev-init-scripts \
    udev-init-scripts-openrc \
    wpa_supplicant \
    shadow \
    nftables \
    hostapd \
    wireless-tools \
    wireless-regdb \
    binutils \
    zstd \
    iw \
    bash \
    jq \
    fastfetch \
    iftop \
    htop \
    nano \
    speedtest-cli \
    openssh-client-common \
    openssh-client-default \
    curl \
    tzdata \
    wget \
    yamllint \
    iperf3 \
    qmi-utils \
    qmi-ping \
    libqmi-bash-completion \
    qmic \
    darkstat \
    btop \
    vnstat \
    util-linux
    
"
# setup alpine
chroot ${CHROOT} ash -l -c "
echo wyref:1::::/home/wyref:/bin/ash | newusers
apk del shadow

rc-update add devfs sysinit
rc-update add dmesg sysinit
rc-update add udev sysinit
rc-update add udev-trigger sysinit
rc-update add udev-settle sysinit
rc-update add udev-postmount default
rc-update add hwclock boot
rc-update add modules boot
rc-update add sysctl boot
rc-update add hostname boot
rc-update add bootmisc boot
rc-update add mount-ro shutdown
rc-update add killprocs shutdown
rc-update add savecache shutdown
rc-update add dropbear default
rc-update add rmtfs default
rc-update add modemmanager default
rc-update add networkmanager default
rc-update add chronyd default
"
echo 'wyref ALL=(ALL:ALL) NOPASSWD: ALL' > ${CHROOT}/etc/sudoers.d/wyref

# add udev rules
cat << EOF > ${CHROOT}/etc/udev/rules.d/10-udc.rules
ACTION=="add", SUBSYSTEM=="udc", RUN+="/sbin/modprobe libcomposite", RUN+="/usr/bin/gt load rndis-os-desc.scheme rndis"
EOF

cat << EOF > ${CHROOT}/etc/udev/rules.d/99-nm-usb0.rules
SUBSYSTEM=="net", ACTION=="add|change|move", ENV{DEVTYPE}=="gadget", ENV{NM_UNMANAGED}="0"
EOF

# enable autologin on console
sed -i '/^tty/ s/^/#/' ${CHROOT}/etc/inittab
echo 'ttyMSM0::respawn:/bin/sh' >> ${CHROOT}/etc/inittab

echo ${HOST_NAME} > ${CHROOT}/etc/hostname
sed -i "/localhost/ s/$/ ${HOST_NAME}/" ${CHROOT}/etc/hosts

# setup NetworkManager
cp configs/*.nmconnection ${CHROOT}/etc/NetworkManager/system-connections
chmod 0600 ${CHROOT}/etc/NetworkManager/system-connections/*
# sed -i '/\[main\]/a dns=dnsmasq' ${CHROOT}/etc/NetworkManager/NetworkManager.conf

mkdir -p ${CHROOT}/boot/extlinux
cp configs/${TYPEDEV}_extlinux.conf ${CHROOT}/boot/extlinux/extlinux.conf

mkdir -p "${CHROOT}/boot/dtbs/qcom"
# copy custom dtb's
cp dtbs/* ${CHROOT}/boot/dtbs/qcom

# update fstab
echo "/dev/mmcblk0p14\t/boot\text2\tdefaults\t0 2" > ${CHROOT}/etc/fstab

# copy gadget-tool templates
cp -a configs/templates ${CHROOT}/etc/gt

# backup rootfs
tar cpzf alpine_rootfs.tgz \
    --exclude="root/*" \
    --exclude="usr/bin/qemu-armhf-static" \
    -C rootfs .
