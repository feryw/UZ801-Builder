#!/bin/sh -e

CHROOT=${CHROOT=$(pwd)/rootfs}
RELEASE=${RELEASE=oldstable}
HOST_NAME=${HOST_NAME=uz801-debian}

rm -rf ${CHROOT}

debootstrap --foreign --arch armhf \
    --keyring /usr/share/keyrings/debian-archive-keyring.gpg ${RELEASE} ${CHROOT}

cp $(which qemu-arm-static) ${CHROOT}/usr/bin

chroot ${CHROOT} qemu-arm-static /bin/bash /debootstrap/debootstrap --second-stage

cat << EOF > ${CHROOT}/etc/apt/sources.list
deb http://deb.debian.org/debian ${RELEASE} main contrib non-free-firmware
deb http://deb.debian.org/debian-security/ ${RELEASE}-security main contrib non-free-firmware
deb http://deb.debian.org/debian ${RELEASE}-updates main contrib non-free-firmware
EOF

mount -t proc proc ${CHROOT}/proc/
mount -t sysfs sys ${CHROOT}/sys/
mount -o bind /dev/ ${CHROOT}/dev/
mount -o bind /dev/pts/ ${CHROOT}/dev/pts/
mount -o bind /run ${CHROOT}/run/

cp scripts/setup.sh ${CHROOT}
chroot ${CHROOT} qemu-arm-static /bin/sh -c /setup.sh

# cleanup
for a in proc sys dev/pts dev run; do
    umount ${CHROOT}/${a}
done;

rm -f ${CHROOT}/setup.sh
echo -n > ${CHROOT}/root/.bash_history

echo ${HOST_NAME} > ${CHROOT}/etc/hostname
sed -i "/localhost/ s/$/ ${HOST_NAME}/" ${CHROOT}/etc/hosts

# setup systemd services
cp -a configs/system/* ${CHROOT}/etc/systemd/system

cp -a scripts/msm-firmware-loader.sh ${CHROOT}/usr/sbin

# setup NetworkManager
cp configs/*.nmconnection ${CHROOT}/etc/NetworkManager/system-connections
chmod 0600 ${CHROOT}/etc/NetworkManager/system-connections/*
sed -i '/\[main\]/a dns=dnsmasq' ${CHROOT}/etc/NetworkManager/NetworkManager.conf

# enable autoconnect for usb0
cat << EOF > ${CHROOT}/etc/udev/rules.d/99-nm-usb0.rules
SUBSYSTEM=="net", ACTION=="add|change|move", ENV{DEVTYPE}=="gadget", ENV{NM_UNMANAGED}="0"
EOF

# install kernel
wget https://github.com/feryw/msm8916-kernel/releases/download/v6.12.63-wyref-gcc10-armv7/linux-image-6.12.63-wyref_6.12.63-ga626e6f4f5d7-2_armhf.deb -O linux-image.deb
cp linux-image.deb ${CHROOT}/tmp/
chroot ${CHROOT} qemu-arm-static /bin/bash -c "dpkg -i /tmp/linux-image.deb"
rm ${CHROOT}/tmp/linux-image.deb

mv ${CHROOT}/boot/vmlinuz-*-wyref ${CHROOT}/boot/vmlinuz
mv ${CHROOT}/boot/System.map-*-wyref ${CHROOT}/boot/System.map

mkdir -p ${CHROOT}/boot/extlinux
cp configs/extlinux.conf ${CHROOT}/boot/extlinux

mkdir -p "${CHROOT}/boot/dtbs"

# copy custom dtb's
cp dtbs/* ${CHROOT}/boot/dtbs

find ${CHROOT}/boot/

# create missing directory
mkdir -p ${CHROOT}/lib/firmware/msm-firmware-loader

# update fstab
echo "PARTUUID=80780b1d-0fe1-27d3-23e4-9244e62f8c46\t/boot\text2\tdefaults\t0 2" > ${CHROOT}/etc/fstab

# backup rootfs
tar cpzf rootfs.tgz --exclude="usr/bin/qemu-arm-static" -C rootfs .
