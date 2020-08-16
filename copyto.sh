#!/bin/bash
# Check
if [ $(whoami) != root ]; then
    echo "Oops! Pleasr run as root."
    exit 1
fi

if [ ! -d "kernel/" ]; then
    echo "No kernel/. Wrong Path!"
    exit 1
fi

# Env
export KERNELDIR=$(pwd)/kernel
export MOUNTPOINT=/run/media/me
export boot=${MOUNTPOINT}/boot
export rootfs=${MOUNTPOINT}/rootfs

# git
cd ${KERNELDIR}
git pull origin

# mount
mkdir ${boot}
mount /dev/sdc1 ${boot}
echo "mount ${boot}"
mkdir ${rootfs}
mount /dev/sdc2 ${rootfs}
echo "mount ${rootfs}"

# mv
cp -a ${KERNELDIR}/lib/modules ${rootfs}/lib/
cp ${KERNELDIR}/Image ${boot}/kernel8.img
cp ${KERNELDIR}/*.dtb ${boot}/
cp ${KERNELDIR}/overlays/* ${boot}/overlays/
rm -rf ${rootfs}/modules/*
cp -a ${KERNELDIR}/lib/modules/* ${rootfs}/modules/
echo "copy complete"

# umount
umount ${MOUNTPOINT}/* && rm -r ${boot} && rm -r ${rootfs}
echo "umount and clean"
