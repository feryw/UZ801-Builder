#!/bin/sh
set -e

echo "========================================================"
echo "            OpenStick Fastboot Flash Tool (Debian)"
echo "========================================================"
echo

echo "[*] Checking Fastboot device connection..."
fastboot devices
echo

echo "[1/4] Flashing Partition Table and Bootloader..."
fastboot flash partition gpt_both0.bin
fastboot flash aboot aboot.mbn
fastboot flash hyp hyp.mbn
fastboot flash rpm rpm.mbn
fastboot flash sbl1 sbl1.mbn
fastboot flash tz tz.mbn

echo
echo "[2/4] Flashing Kernel and Boot Image..."
fastboot flash boot boot.bin

echo
echo "[3/4] Flashing Debian Rootfs..."
if [ ! -f "rootfs.bin" ]; then
    echo "[!] Error: rootfs.bin not found!"
    exit 1
fi
fastboot flash rootfs rootfs.bin

echo
echo "[4/4] Restoring Hardware and Modem Partitions..."
for part in fsc fsg modem modemst1 modemst2 persist sec; do
    if [ -f "${part}.bin" ]; then
        echo "[*] Flashing ${part}.bin..."
        fastboot flash "${part}" "${part}.bin"
    else
        echo "[!] Warning: ${part}.bin not found, skipping..."
    fi
done

echo
echo "[*] All partitions flashed successfully! Rebooting device..."
fastboot reboot

echo "[*] Flash completed."