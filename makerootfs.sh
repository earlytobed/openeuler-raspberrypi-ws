#!/bin/bash
# Env
export WORKDIR=$(pwd)
export KERNEL_REPO=kernel

clean(){
    cd ${WORKDIR}
    rm -rf openEuler_raspi.img openEuler_raspi.img.gz rootfs/ boot/ root/ rootfs.tar
}

prepare_rootfs(){
    cd ${WORKDIR}
    # RPM db
    mkdir ${WORKDIR}/rootfs
    mkdir -p ${WORKDIR}/rootfs/var/lib/rpm
    rpm --root ${WORKDIR}/rootfs/ --initdb

    # test locale shrink
    mkdir -p ${WORKDIR}/rootfs/etc/rpm
    chmod a+rX ${WORKDIR}/rootfs/etc/rpm
    echo "%_install_langs en_US" > ${WORKDIR}/rootfs/etc/rpm/macros.image-language-conf

    # openEuler
    # 会在 ${WORKDIR}/rootfs 下生成三个文件夹: etc/ usr/ var/
    rpm -ivh --nodeps --root ${WORKDIR}/rootfs/ http://repo.openeuler.org/openEuler-20.03-LTS/everything/aarch64/Packages/openEuler-release-20.03LTS-33.oe1.aarch64.rpm
    # yum
    mkdir -p ${WORKDIR}/rootfs/etc/yum.repos.d
    # curl -o ${WORKDIR}/rootfs/etc/yum.repos.d/openEuler-20.03-LTS.repo https://gitee.com/src-openeuler/openEuler-repos/raw/openEuler-20.03-LTS/generic.repo
    echo -e "[OS]
name=OS
baseurl=https://isrc.iscas.ac.cn/eulixos/repo/test/1/packages/aarch64/
enabled=1
gpgcheck=0

[source]
name=source
baseurl=https://isrc.iscas.ac.cn/eulixos/repo/test/1/packages/source/
enabled=1
gpgcheck=0" > ${WORKDIR}/rootfs/etc/yum.repos.d/openEuler-20.03-LTS.repo

    # dnf
    dnf --installroot=${WORKDIR}/rootfs/ localinstall ./dnf-4.2.15-8.noarch.rpm --nogpgcheck
    # others
    # dnf --installroot=${WORKDIR}/rootfs/ makecache
    # dnf --installroot=${WORKDIR}/rootfs/ install -y alsa-utils wpa_supplicant vim net-tools iproute iputils NetworkManager openssh-server passwd hostname ntp bluez pulseaudio-module-bluetooth security-tool crda
    # Configs
    ## hosts
    ### Use rootfs-sample
    ## DNS
    ### Use rootfs-sample
    ## IP Auto
    ### Use rootfs-sample
    cp -a rootfs-sample/etc/* ${WORKDIR}/rootfs/etc/

    # firmware
    mkdir -p ${WORKDIR}/rootfs/lib/firmware ${WORKDIR}/rootfs/usr/bin ${WORKDIR}/rootfs/lib/udev/rules.d ${WORKDIR}/rootfs/lib/systemd/system
    cp -a ${WORKDIR}/bluez-firmware/broadcom/* ${WORKDIR}/rootfs/lib/firmware/
    cp -a ${WORKDIR}/firmware-nonfree/brcm/ ${WORKDIR}/rootfs/lib/firmware/
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

    ## size
    ROOTFS_SIZE=$(du -sh --block-size=1MiB ${WORKDIR}/rootfs | awk '{print $1}')
    touch ${WORKDIR}/${ROOTFS_SIZE}
}

if [ -n "$1" ]; then
    if [ $1 == "clean" ]; then
        echo "cleaning"
        clean && exit 0
    fi
fi

clean
prepare_rootfs
