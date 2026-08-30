#!/bin/sh -e

OUTDIR="files"
BOARD="${BOARD:-yiming-uz801v3}"
FWDIR="firmware/${BOARD}"

if [ ! -d "${FWDIR}" ]; then
    FWDIR="firmware"
fi

mkdir -p "${OUTDIR}"

if [ -d "${FWDIR}" ] && [ -n "$(ls -A "${FWDIR}" 2>/dev/null)" ]; then
    echo "Copying custom firmware partitions from '${FWDIR}' to '${OUTDIR}/'..."
    cp -a "${FWDIR}"/* "${OUTDIR}/"
    echo "Custom firmware partitions copied successfully."
else
    echo "Warning: '${FWDIR}' directory is empty or does not exist. Skipping."
fi