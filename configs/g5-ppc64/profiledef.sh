#!/hint/bash
# Profile: PowerMac G5 (Late 2005)
# ArchPOWER ppc64 with GRUB via OpenFirmware  `boot ud:2,\grub` to boot from USB                                                                                                                                                                                                  
#
# Based on: https://github.com/kth5/archpower/wiki/Installation-%7C--NewWorld-PowerMac-with-Grub
#
# Since the Docker host kernel lacks the hfs module, we can't kernel-mount
# the HFS bootstrap partition. Instead we use hfsutils (userspace HFS tools)
# to achieve the same result as the wiki's mount-based approach:
#   hformat  → mkfs.hfs / mount
#   hcopy    → cp
#   hattrib  → bless
#
# Boot flow:
#   OF loads grub from HFS bootstrap (blessed tbxi file)
#   → GRUB finds ext4 root by UUID (embedded early config)
#   → GRUB loads modules + grub.cfg from /boot/grub on ext4

device_name="PowerMac G5"
arch="ppc64"
bootstrap_packages=("archpower-keyring" "base")

# Image layout — Apple Partition Map
# (APM auto-creates a partition map entry; our partitions start after it)
img_size="2G"
partition_table="mac"
partitions=(
    "hfs   32M   bootstrap"
    "ext4  rest  root"
)

# Source rootfs — download from https://archlinuxpower.org
tarball="${script_dir}/ArchPOWER-ppc64-latest.tar.gz"

# Personal credentials (username/password for the default user)
# shellcheck source=/dev/null
source "${script_dir}/personal-creds.conf" 2>/dev/null || true

# Package operations in chroot
# Based on archiso/configs/releng-ppc64/packages.ppc64
packages_install=(
    # Core — must come first
    "base"

    # ArchPOWER specific
    "archpower-keyring"
    "brotli"
    "haveged"
    "hfsutils"
    "hfsprogs"
    "iprutils"
    "linux-ppc64"
    "mac-fdisk"

    # System tools
    "arch-install-scripts"
    "bind"
    "btrfs-progs"
    "diffutils"
    "dosfstools"
    "ethtool"
    "exfatprogs"
    "hdparm"
    "lsscsi"
    "lvm2"
    "mdadm"
    "mkinitcpio"
    "mtools"
    "ntfs-3g"
    "parted"
    "partclone"
    "partimage"
    "sdparm"
    "smartmontools"
    "squashfs-tools"
    "testdisk"
    "usbutils"
    "xfsprogs"

    # Networking
    "dhclient"
    "dhcpcd"
    "dnsmasq"
    "gnu-netcat"
    "iwd"
    "linux-atm"
    "modemmanager"
    "nbd"
    "ndisc6"
    "nfs-utils"
    "networkmanager"
    "nmap"
    "openssh"
    "ppp"
    "pptpclient"
    "rp-pppoe"
    "rsync"
    "systemd-resolvconf"
    "usb_modeswitch"
    "vpnc"
    "wireless-regdb"
    "wireless_tools"
    "wpa_supplicant"
    "wvdial"
    "xl2tpd"

    # Shells & terminal
    "grml-zsh-config"
    "kitty-terminfo"
    "rxvt-unicode-terminfo"
    "tmux"
    "zsh"

    # Editors & misc
    "man-db"
    "man-pages"
    "nano"
    "vim"
    "sudo"

    # Audio
    "alsa-utils"

    # Web / transfer
    "darkhttpd"
    "lftp"
    "lynx"

    # Chat
    "irssi"

    # Braille
    "brltty"

    # RAID
    "dmraid"

    # Boot — G5 specific
    "grub"
)

# Chroot hooks — grub modules/config on ext4, locale, services
post_install() {
    mkdir -p /boot/grub/powerpc-ieee1275 /boot/grub/fonts
    cp /usr/lib/grub/powerpc-ieee1275/*.mod /boot/grub/powerpc-ieee1275/
    cp /usr/lib/grub/powerpc-ieee1275/*.lst /boot/grub/powerpc-ieee1275/ 2>/dev/null || true
    cp /usr/share/grub/unicode.pf2 /boot/grub/fonts/ 2>/dev/null || true
    grub-mkconfig -o /boot/grub/grub.cfg
    locale-gen
    systemctl enable NetworkManager
    systemctl enable sshd

    # Unlock root for console login (password set in post_build if creds provided)
    passwd -d root
}

# Host-side hook — build GRUB core image and install to HFS bootstrap
post_build() {
    local bootstrap_dev root_dev root_uuid
    bootstrap_dev="$(_part_dev 1)"
    root_dev="$(_part_dev 2)"
    root_uuid="$(blkid -s UUID -o value "${root_dev}")"

    # Early config embedded in core.elf — tells GRUB how to find the
    # ext4 root partition where /boot/grub/grub.cfg and modules live
    cat > "${mount_root}/root/grub-early.cfg" <<EOCFG
search.fs_uuid ${root_uuid} root
set prefix=(\$root)/boot/grub
EOCFG

    _msg "  root UUID: ${root_uuid}"
    _msg "  bootstrap: ${bootstrap_dev}"

    # All grub/hfs operations run inside the ppc64 chroot (via QEMU)
    env -u TMPDIR arch-chroot "${mount_root}" /bin/bash -ec "
        set -x

        # Build GRUB core image for Open Firmware
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

        # Format HFS, copy core.elf, bless for OF
        hformat -l bootstrap ${bootstrap_dev}
        hmount ${bootstrap_dev}
        hcopy /root/core.elf :grub
        hattrib -t tbxi -c UNIX :grub
        hattrib -b :
        hls -la :
        humount

        rm -f /root/core.elf /root/grub-early.cfg
    "

    # Create user from personal-creds.conf
    if [[ -n "${USERNAME:-}" && -n "${PASSWORD:-}" ]]; then
        _msg "  Creating user: ${USERNAME}"
        env -u TMPDIR arch-chroot "${mount_root}" /bin/bash -ec "
            useradd -m -G wheel '${USERNAME}'
            echo '${USERNAME}:${PASSWORD}' | chpasswd
            echo 'root:${PASSWORD}' | chpasswd
            sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
        "
    else
        _warn "No personal-creds.conf — root has empty password"
    fi

    # Flush block device cache
    sync
}

# SSH host key generation
generate_ssh_keys=true

# Output compression
compression_opts=("-T0" "-6")
