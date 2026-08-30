@echo off
setlocal enabledelayedexpansion

echo ========================================================
echo             OpenStick Fastboot Flash Tool (Debian)
echo ========================================================
echo.

echo [*] Checking Fastboot device connection...
fastboot devices
echo.
echo Please ensure your device is listed above.
echo Press any key to begin flashing...
pause >nul

echo.
echo [1/4] Flashing Partition Table and Bootloader...
fastboot flash partition gpt_both0.bin || goto :error
fastboot flash aboot aboot.mbn || goto :error
fastboot flash hyp hyp.mbn || goto :error
fastboot flash rpm rpm.mbn || goto :error
fastboot flash sbl1 sbl1.mbn || goto :error
fastboot flash tz tz.mbn || goto :error

echo.
echo [2/4] Flashing Kernel and Boot Image...
fastboot flash boot boot.bin || goto :error

echo.
echo [3/4] Flashing Debian Rootfs...
if not exist rootfs.bin (
    echo [!] Error: rootfs.bin not found!
    goto :error
)
fastboot flash rootfs rootfs.bin || goto :error

echo.
echo [4/4] Restoring Hardware and Modem Partitions...
for %%p in (fsc fsg modem modemst1 modemst2 persist sec) do (
    if exist %%p.bin (
        echo [*] Flashing %%p.bin...
        fastboot flash %%p %%p.bin || goto :error
    ) else (
        echo [!] Warning: %%p.bin not found, skipping...
    )
)

echo.
echo [*] All partitions flashed successfully! Rebooting device...
fastboot reboot

echo.
echo [*] Flash completed.
pause
exit /b 0

:error
echo.
echo [X] Flashing failed! Please check the USB connection and try again.
pause
exit /b 1