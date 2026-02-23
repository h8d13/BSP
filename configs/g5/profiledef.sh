#!/hint/bash
# Profile: PowerMac G5 (Late 2005)
# ArchPOWER ppc64 with GRUB via OpenFirmware — `boot ud:2,\grub`
#
# Boot flow:
#   OF loads grub from HFS bootstrap (blessed tbxi file)
#   → GRUB finds ext4 root by UUID (embedded early config)
#   → GRUB loads modules + grub.cfg from /boot/grub on ext4

device_name="PowerMac G5"
arch="ppc64"
bootstrap_packages=("archpower-keyring" "base")

# Image layout — Apple Partition Map
img_size="2G"
partition_table="mac"
partitions=(
    "hfs   32M   bootstrap"
    "ext4  rest  root"
)

# Source rootfs
tarball="${script_dir}/in/ArchPOWER-ppc64-latest.tar.gz"

# Personal credentials (username/password for the default user)
# shellcheck source=/dev/null
source "${script_dir}/personal-creds.conf" 2>/dev/null || true

# Packages to install in chroot
packages_install=(
    "archpower-keyring"
    "linux-ppc64"
    "mkinitcpio"
    "grub"
    "hfsutils"
    "hfsprogs"
    "mac-fdisk"
    "networkmanager"
    "openssh"
    "sudo"

    # System tools
    # "arch-install-scripts"
    # "bind"
    # "brotli"
    # "btrfs-progs"
    "diffutils"
    # "dosfstools"
    "ethtool"
    # "exfatprogs"
    # "haveged"
    "hdparm"
    # "iprutils"
    # "lsscsi"
    # "lvm2"
    # "mdadm"
    # "mtools"
    # "ntfs-3g"
    "parted"
    # "partclone"
    # "partimage"
    # "sdparm"
    "smartmontools"
    # "squashfs-tools"
    # "testdisk"
    "usbutils"
    # "xfsprogs"

    # Networking
    # "dhclient"
    "dhcpcd"
    # "dnsmasq"
    "gnu-netcat"
    "iwd"
    # "linux-atm"
    # "modemmanager"
    # "nbd"
    # "ndisc6"
    "nfs-utils"
    "nmap"
    # "ppp"
    # "pptpclient"
    # "rp-pppoe"
    "rsync"
    # "systemd-resolvconf"
    # "usb_modeswitch"
    # "vpnc"
    # "wireless-regdb"
    # "wireless_tools"
    "wpa_supplicant"
    # "wvdial"
    # "xl2tpd"

    # Optional essentials
    # "alsa-utils"
    # "brltty"
    # "darkhttpd"
    # "dmraid"
    # "grml-zsh-config"
    # "irssi"
    # "kitty-terminfo"
    # "lftp"
    # "lynx"
    "man-db"
    "man-pages"
    "nano"
    # "rxvt-unicode-terminfo"
    # "tmux"
    "vim"
    "zsh"
)

# Chroot hooks
pre_install() {
    pacman-key --init
    pacman-key --populate archpower
}

post_install() {
    mkdir -p /boot/grub/powerpc-ieee1275 /boot/grub/fonts
    cp /usr/lib/grub/powerpc-ieee1275/*.mod /boot/grub/powerpc-ieee1275/
    cp /usr/lib/grub/powerpc-ieee1275/*.lst /boot/grub/powerpc-ieee1275/ 2>/dev/null || true
    cp /usr/share/grub/unicode.pf2 /boot/grub/fonts/ 2>/dev/null || true
    grub-mkconfig -o /boot/grub/grub.cfg
    locale-gen
    systemctl enable NetworkManager
    if [[ "${GENSSH:-false}" == "true" ]]; then
        systemctl enable sshd
    fi
}

# Host-side hook — build GRUB core image and install to HFS bootstrap
post_build() {
    local bootstrap_dev root_dev root_uuid
    bootstrap_dev="$(_part_dev 1)"
    root_dev="$(_part_dev 2)"
    root_uuid="$(blkid -s UUID -o value "${root_dev}")"

    cat > "${mount_root}/root/grub-early.cfg" <<EOCFG
search.fs_uuid ${root_uuid} root
set prefix=(\$root)/boot/grub
EOCFG

    _msg "  root UUID: ${root_uuid}"
    _msg "  bootstrap: ${bootstrap_dev}"

    env -u TMPDIR arch-chroot "${mount_root}" /bin/bash -ec "
        set -x

        grub-mkimage \
            --format=powerpc-ieee1275 \
            --output=/root/core.elf \
            --config=/root/grub-early.cfg \
            --prefix='/boot/grub' \
            --directory=/usr/lib/grub/powerpc-ieee1275 \
            part_apple ext2 normal boot linux echo search search_fs_uuid \
            search_fs_file search_label configfile

        ls -la /root/core.elf
        file /root/core.elf

        hformat -l bootstrap ${bootstrap_dev}
        hmount ${bootstrap_dev}
        hcopy /root/core.elf :grub
        hattrib -t tbxi -c UNIX :grub
        hattrib -b :
        hls -la :
        humount

        rm -f /root/core.elf /root/grub-early.cfg
    "

    # Create user from personal-creds.conf and lock root, or unlock root for console
    if [[ -n "${USERNAME:-}" && -n "${PASSWORD:-}" ]]; then
        _msg "  Creating user: ${USERNAME} (root locked)"
        env -u TMPDIR arch-chroot "${mount_root}" /bin/bash -ec "
            useradd -m -G wheel '${USERNAME}'
            echo '${USERNAME}:${PASSWORD}' | chpasswd
            passwd -l root
            sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
        "
    else
        _warn "No personal-creds.conf — root has empty password"
        env -u TMPDIR arch-chroot "${mount_root}" passwd -d root
    fi

    sync
}

generate_ssh_keys="${GENSSH:-false}"
