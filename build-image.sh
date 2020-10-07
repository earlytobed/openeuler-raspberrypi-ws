#!/bin/bash
# Environment
export WORKDIR=$(pwd)
export KERNEL_REPO=kernel
eulixos=$(pwd)/raspi-configs/eulixos-daily.repo
lts=$(pwd)/raspi-configs/openEuler-20.03-LTS.repo.repo
mainline=$(pwd)/raspi-configs/openEuler-20.03-LTS.repo.repo
TARGET=

clean(){
    cd ${WORKDIR}
    echo "cleaning"
    rm -rf openEuler_raspi.img openEuler_raspi.img.gz rootfs/ boot/ root/ rootfs.tar
}

prepare_rootfs(){
    cd ${WORKDIR}
    # RPM db
    mkdir ${WORKDIR}/rootfs
    mkdir -p ${WORKDIR}/rootfs/var/lib/rpm
    rpm --root ${WORKDIR}/rootfs/ --initdb
    mkdir -p ${WORKDIR}/rootfs/etc/rpm
    chmod a+rX ${WORKDIR}/rootfs/etc/rpm

    # openEuler
    # 会在 ${WORKDIR}/rootfs 下生成三个文件夹: etc/ usr/ var/
    rpm -ivh --nodeps --root ${WORKDIR}/rootfs/ http://repo.openeuler.org/openEuler-20.03-LTS/everything/aarch64/Packages/openEuler-release-20.03LTS-33.oe1.aarch64.rpm
    # yum
    mkdir -p ${WORKDIR}/rootfs/etc/yum.repos.d
    # Mainline glibc
    cp ${mainline} ${WORKDIR}/rootfs/etc/yum.repos.d/
    dnf --installroot=${WORKDIR}/rootfs/ --nodocs install glibc -y
    # EulixOS.daily.repo else
    cp ${eulixos} ${WORKDIR}/rootfs/etc/yum.repos.d/
    # dnf
    dnf --installroot=${WORKDIR}/rootfs/ --nodocs install dnf -y
    # others
    dnf --installroot=${WORKDIR}/rootfs/ makecache
    dnf --installroot=${WORKDIR}/rootfs/ --nodocs install NetworkManager openssh-server openssh-clients -y
    # dnf --installroot=${WORKDIR}/rootfs/ --nodocs install -y alsa-utils wpa_supplicant vim net-tools iproute iputils NetworkManager openssh-server passwd hostname ntp bluez pulseaudio-module-bluetooth security-tool crda
    dnf --installroot=${WORKDIR}/rootfs/ autoremove
    dnf --installroot=${WORKDIR}/rootfs/ clean all

    # Configs
    ## hosts
    ### Use rootfs-sample
    ## DNS
    ### Use rootfs-sample
    ## IP Auto
    ### Use rootfs-sample
    cp -a raspi-configs/rootfs-sample/etc/* ${WORKDIR}/rootfs/etc/

    # firmware
    mkdir -p ${WORKDIR}/rootfs/lib/firmware ${WORKDIR}/rootfs/usr/bin ${WORKDIR}/rootfs/lib/udev/rules.d ${WORKDIR}/rootfs/lib/systemd/system
    cp -a ${WORKDIR}/bluez-firmware/broadcom/* ${WORKDIR}/rootfs/lib/firmware/
    mkdir -p ${WORKDIR}/rootfs/lib/firmware/brcm/
    cp ${WORKDIR}/firmware-nonfree/brcm/brcmfmac43455* ${WORKDIR}/rootfs/lib/firmware/brcm/
    cp -a raspberrypi-sys-mods/etc.armhf/udev/rules.d/99-com.rules ${WORKDIR}/rootfs/lib/udev/rules.d/
    cp -a pi-bluetooth/usr/bin/* ${WORKDIR}/rootfs/usr/bin/
    cp -a pi-bluetooth/lib/udev/rules.d/90-pi-bluetooth.rules ${WORKDIR}/rootfs/lib/udev/rules.d/
    cp -a pi-bluetooth/debian/pi-bluetooth.bthelper\@.service ${WORKDIR}/rootfs/lib/systemd/system/bthelper\@.service
    cp -a pi-bluetooth/debian/pi-bluetooth.hciuart.service ${WORKDIR}/rootfs/lib/systemd/system/hciuart.service
    ## bluetooth
    mv ${WORKDIR}/rootfs/lib/firmware/BCM43430A1.hcd ${WORKDIR}/rootfs/lib/firmware/brcm/
    mv ${WORKDIR}/rootfs/lib/firmware/BCM4345C0.hcd ${WORKDIR}/rootfs/lib/firmware/brcm/
    ## kernel object
    cp -a ${WORKDIR}/${KERNEL_REPO}/lib/modules ${WORKDIR}/rootfs/lib/
}

rootfs_config(){
    # rootfs config
    ## mount
    mount --bind /dev ${WORKDIR}/rootfs/dev
    mount -t proc /proc ${WORKDIR}/rootfs/proc
    mount -t sysfs /sys ${WORKDIR}/rootfs/sys
    ## chroot
    ## passwd root
    ## hostname
    ## timezone
    ## hciuart
    ## exit
    chroot ${WORKDIR}/rootfs /bin/bash -c "systemctl enable sshd; echo root:admin | chpasswd; echo openEuler-raspberrypi > /etc/hostname; rm -f /etc/localtime; ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime; systemctl enable hciuart; exit;"
    ## umount
    umount -l ${WORKDIR}/rootfs/dev
    umount -l ${WORKDIR}/rootfs/proc
    umount -l ${WORKDIR}/rootfs/sys
    ## size
    ROOTFS_SIZE=$(du -sh --block-size=1MiB ${WORKDIR}/rootfs | awk '{print $1}')
}

create_image_parted_losetup_kpartx_format_mkdir_mount_fstab(){
    cd ${WORKDIR}
    # dd
    dd if=/dev/zero of=openEuler_raspi.img bs=1M count=$[64+ROOTFS_SIZE+200]
    # parted
    parted -s openEuler_raspi.img mklabel msdos mkpart primary fat32 4M 64M set 1 boot on set 1 lba on mkpart primary ext4 64M 100%
    # losetup
    LOOP_DEVICE=$(losetup -f --show openEuler_raspi.img | tr -d "/dev/loop")
    # kpartx
    kpartx -av /dev/loop${LOOP_DEVICE}
    # format
    # boot
    mkfs.vfat -n boot /dev/mapper/loop${LOOP_DEVICE}p1
    # rootfs
    mkfs.ext4 /dev/mapper/loop${LOOP_DEVICE}p2
    # swap
    # mkswap /dev/mapper/loop${LOOP_DEVICE}p3

    # mkdir root boot
    mkdir ${WORKDIR}/root ${WORKDIR}/boot
    # mount
    mount -t vfat -o uid=root,gid=root,umask=0000 /dev/mapper/loop${LOOP_DEVICE}p1 ${WORKDIR}/boot/
    mount -t ext4 /dev/mapper/loop${LOOP_DEVICE}p2 ${WORKDIR}/root/
    ## get blkid
    BOOT_UUID=$(blkid -s UUID -o value /dev/mapper/loop${LOOP_DEVICE}p1)
    ROOTFS_UUID=$(blkid -s UUID -o value /dev/mapper/loop${LOOP_DEVICE}p2)
    # SWAP_UUID=$(blkid -s UUID -o value /dev/mapper/loop${LOOP_DEVICE}p3)

    # fstab
    # echo -e "UUID=${BOOT_UUID}      /boot   vfat    defaults,noatime 0 0\nUUID=${ROOTFS_UUID}    /       ext4    defaults,noatime 0 0\nUUID=${SWAP_UUID}      swap    swap    defaults,noatime 0 0" > ${WORKDIR}/rootfs/etc/fstab
    echo -e "UUID=${BOOT_UUID}      /boot   vfat    defaults,noatime 0 0\nUUID=${ROOTFS_UUID}    /       ext4    defaults,noatime 0 0" > ${WORKDIR}/rootfs/etc/fstab
}

after_mount_copy_boot(){
    cd ${WORKDIR}/boot
    mkdir overlays/
    cp -r ${WORKDIR}/firmware/boot/* ${WORKDIR}/boot/
    rm *.dtb kernel.img kernel7*.img
    # kernel
    cp ${WORKDIR}/${KERNEL_REPO}/Image ${WORKDIR}/boot/kernel8.img
    # device tree
    cp ${WORKDIR}/${KERNEL_REPO}/bcm2711-rpi-4-b.dtb ${WORKDIR}/boot/
    cp ${WORKDIR}/${KERNEL_REPO}/overlays/* ${WORKDIR}/boot/overlays/
    # add cmdline.txt
    echo "console=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline rootwait" > cmdline.txt
}

after_mount_copy_rootfs(){
    cd ${WORKDIR}/rootfs/
    tar cpf ${WORKDIR}/rootfs.tar .
    cd ${WORKDIR}/root
    tar xpf ${WORKDIR}/rootfs.tar -C .
}

sync_and_umount(){
    # save and umount
    ## sync
    sync
    ## wait
    sleep 5
    ## umount
    cd ${WORKDIR}
    umount root
    umount boot
    kpartx -d /dev/loop${LOOP_DEVICE}
    losetup -d /dev/loop${LOOP_DEVICE}
}

if [ -n "$1" ]; then
    if [ $1 == "clean" ]; then
        echo "cleaning"
        clean && exit 0
    fi
fi

clean
prepare_rootfs
rootfs_config
create_image_parted_losetup_kpartx_format_mkdir_mount_fstab
after_mount_copy_boot
after_mount_copy_rootfs
sync_and_umount
gzip openEuler_raspi.img
echo done!