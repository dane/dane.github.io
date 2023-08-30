#!/bin/bash

echo "Export env-vars"
export DEV="/dev/nvme0n1"
export DM="${DEV##*/}"
export DEVP="${DEV}$( if [[ "$DEV" =~ "nvme" ]]; then echo "p"; fi )"
export DM="${DM}$( if [[ "$DM" =~ "nvme" ]]; then echo "p"; fi )"

echo "Partition disk"
sgdisk --print $DEV
sgdisk --zap-all $DEV
sgdisk --new=1:0:+768M $DEV
sgdisk --new=2:0:+2M $DEV
sgdisk --new=3:0:+128M $DEV
sgdisk --new=5:0:0 $DEV
sgdisk --typecode=1:8301 --typecode=2:ef02 --typecode=3:ef00 --typecode=5:8301 $DEV
sgdisk --change-name=1:/boot --change-name=2:GRUB --change-name=3:EFI-SP --change-name=5:rootfs $DEV
sgdisk --hybrid 1:2:3 $DEV
sgdisk --print $DEV

echo "Cryptsetup and unlock"
cryptsetup luksFormat --type=luks1 ${DEVP}1
cryptsetup luksFormat ${DEVP}5
cryptsetup open ${DEVP}1 LUKS_BOOT
cryptsetup open ${DEVP}5 ${DM}5_crypt
ls /dev/mapper/

echo "mkfs stuff"
mkfs.ext4 -L boot /dev/mapper/LUKS_BOOT
mkfs.vfat -F 16 -n EFI-SP ${DEVP}3

echo "Generate VGNAME"
flavour="$( sed -n 's/.*cdrom:\[\([^ ]*\).*/\1/p' /etc/apt/sources.list )"
release="$( lsb_release -sr | tr -d . )"
if [ ${release} -ge 2204 ]; then VGNAME="vg${flavour,,}"; else VGNAME="${flavour}--vg"; fi
export VGNAME

echo "pv things"
pvcreate /dev/mapper/${DM}5_crypt
vgcreate "${VGNAME}" /dev/mapper/${DM}5_crypt
lvcreate -L 4G -n swap_1 "${VGNAME}"
lvcreate -l 80%FREE -n root "${VGNAME}"
