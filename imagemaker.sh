#!/bin/bash
# Env
export WORKDIR=$(pwd)

# RPM db
mkdir ${WORKDIR}/rootfs
mkdir -p ${WORKDIR}/rootfs/var/lib/rpm
rpm --root ${WORKDIR}/rootfs/ --initdb

# openEuler
# 会在 ${WORKDIR}/rootfs 下生成三个文件夹: etc/ usr/ var/
rpm -ivh --nodeps --root ${WORKDIR}/rootfs/ http://repo.openeuler.org/openEuler-20.03-LTS/everything/aarch64/Packages/openEuler-release-20.03LTS-33.oe1.aarch64.rpm

# yum
mkdir -p ${WORKDIR}/rootfs/etc/yum.repos.d
curl -o ${WORKDIR}/rootfs/etc/yum.repos.d/openEuler-20.03-LTS.repo https://gitee.com/src-openeuler/openEuler-repos/raw/openEuler-20.03-LTS/generic.repo

# dnf
dnf --installroot=${WORKDIR}/rootfs/ install dnf --nogpgcheck -y

# others
dnf --installroot=${WORKDIR}/rootfs/ makecache
dnf --installroot=${WORKDIR}/rootfs/ install -y alsa-utils wpa_supplicant vim net-tools iproute iputils NetworkManager openssh-server passwd hostname ntp bluez pulseaudio-module-bluetooth

# Configs
## hosts
### Use rootfs-sample
## DNS
### Use rootfs-sample
## IP Auto
### Use rootfs-sample
cp -r roorfs-sample/etc/* ${WORKDIR}/rootfs/etc/

# rootfs ~
## firmware
mkdir -p ${WORKDIR}/rootfs/lib/firmware ${WORKDIR}/rootfs/usr/bin ${WORKDIR}/rootfs/lib/udev/rules.d ${WORKDIR}/rootfs/lib/systemd/system
cp ${WORKDIR}/bluez-firmware/broadcom/* ${WORKDIR}/rootfs/lib/firmware/
cp -r ${WORKDIR}/firmware-nonfree/brcm/ ${WORKDIR}/rootfs/lib/firmware/
cp raspberrypi-sys-mods/etc.armhf/udev/rules.d/99-com.rules ${WORKDIR}/rootfs/lib/udev/rules.d/
cp pi-bluetooth/usr/bin/* ${WORKDIR}/rootfs/usr/bin/
cp pi-bluetooth/lib/udev/rules.d/90-pi-bluetooth.rules ${WORKDIR}/rootfs/lib/udev/rules.d/
cp pi-bluetooth/debian/pi-bluetooth.bthelper\@.service ${WORKDIR}/rootfs/lib/systemd/system/bthelper\@.service
cp pi-bluetooth/debian/pi-bluetooth.hciuart.service ${WORKDIR}/rootfs/lib/systemd/system/hciuart.service
## bluetooth
mv ${WORKDIR}/rootfs/lib/firmware/BCM43430A1.hcd ${WORKDIR}/rootfs/lib/firmware/brcm/
mv ${WORKDIR}/rootfs/lib/firmware/BCM4345C0.hcd ${WORKDIR}/rootfs/lib/firmware/brcm/
## kernel object
cp -r ${WORKDIR}/${KERNEL_REPO}/lib/modules ${WORKDIR}/rootfs/lib/

# rootfs config
## mount
mount --bind /dev ${WORKDIR}/rootfs/dev
mount -t proc /proc ${WORKDIR}/rootfs/proc
mount -t sysfs /sys ${WORKDIR}/rootfs/sys
## chroot
chroot ${WORKDIR}/rootfs /bin/bash
## ssh
systemctl enable ssh
## passwd root
passwd root
## hostname
echo openEuler-raspberrypi > /etc/hostname
## timezone
ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
## hciuart
systemctl enable hciuart
## exit
exit
## umount
umount -l ${WORKDIR}/rootfs/dev
umount -l ${WORKDIR}/rootfs/proc
umount -l ${WORKDIR}/rootfs/sys

# make image
## du
BOOT_SIZE=du -sh --block-size=1MiB ${WORKDIR}/firmware/boot | awk '{print $1}'
ROOTFS_SIZE=du -sh --block-size=1MiB ${WORKDIR}/rootfs | awk '{print $1}'
## image
cd ${WORKDIR}
dd if=/dev/zero of=openEuler_raspi.img bs=1M count=???

# fdisk 
FDISK=$(which fdisk)
${FDISK} openEuler_raspi.img &> /dev/null <<EOF
n
p
1

+${BOOT_SIZE}M
n
p
2

+${ROOTFS_SIZE}M
n
p
3


wq
EOF
## losetup
LOOP_DEVICE=$(losetup -f --show openEuler_raspi.img) | tr -d "/dev/loop"
## kpartx
kpartx -av /dev/loop${LOOP_DEVICE}
## format
## boot
mkfs.vfat -n boot /dev/mapper/loop${LOOP_DEVICE}p1
## rootfs
mkfs.ext4 /dev/mapper/loop${LOOP_DEVICE}p2
## swap
mkswap /dev/mapper/loop${LOOP_DEVICE}p3

## 
mkdir ${WORKDIR}/root ${WORKDIR}/boot
# mount
mount -t vfat -o uid=root,gid=root,umask=0000 /dev/mapper/loop${LOOP_DEVICE}p1 ${WORKDIR}/boot/
mount -t ext4 /dev/mapper/loop${LOOP_DEVICE}p2 ${WORKDIR}/root/
## get blkid
BOOT_UUID=$(blkid -s UUID -o value /dev/mapper/loop${LOOP_DEVICE}p1)
ROOTFS_UUID=$(blkid -s UUID -o value /dev/mapper/loop${LOOP_DEVICE}p2)
SWAP_UUID=$(blkid -s UUID -o value /dev/mapper/loop${LOOP_DEVICE}p3)
## fstab
cat > rootfs/etc/fstab<<EOF
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a device; this may
# be used with UUID= as a more robust way to name devices that works even if
# disks are added and removed. See fstab(5).
#
# <file system>  <mount point>  <type>  <options>  <dump>  <pass>
UUID=${BOOT_UUID}      /boot   vfat    defaults,noatime 0 0
UUID=${ROOTFS_UUID}    /       ext4    defaults,noatime 0 0
UUID=${SWAP_UUID}      swap    swap    defaults,noatime 0 0
EOF
## copy rootfs
cd ${WORKDIR}/rootfs/
tar cpf ${WORKDIR}/rootfs.tar .
cd ${WORKDIR}/root
tar xpf ${WORKDIR}/rootfs.tar -C .
## copy boot
cd ${WORKDIR}/firmware/boot
tar cf ${WORKDIR}/boot.tar ./
cd ${WORKDIR}/boot
tar xf ${WORKDIR}/boot.tar -C .

# save and umount
## sync
sync
## umount
umount ${WORKDIR}/root
umount ${WORKDIR}/boot
kpartx -d /dev/loop${LOOP_DEVICE}
losetup -d /dev/loop${LOOP_DEVICE}

# done
echo done!
