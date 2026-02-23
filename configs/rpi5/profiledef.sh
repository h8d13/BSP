#!/hint/bash
# Profile: Raspberry Pi 5 Model B
# Arch Linux ARM with linux-rpi kernel

device_name="Raspberry Pi 5 Model B"
arch="aarch64"
bootstrap_packages=("archlinuxarm-keyring" "base")

# Image layout
img_size="4G"
partition_table="msdos"
partitions=(
    "fat32  512M  boot"
    "ext4   rest  root"
)

# Source rootfs
tarball="${script_dir}/ArchLinuxARM-rpi-aarch64-latest.tar.gz"

# Personal credentials
source "${script_dir}/personal-creds.conf" 2>/dev/null || true

# Package operations in chroot
packages_remove=("linux-aarch64" "uboot-raspberrypi")
packages_install=("linux-rpi" "raspberrypi-bootloader" "firmware-raspberrypi" "openssh")

# Chroot commands to run before package operations (keyring init, etc.)
pre_install() {
    pacman-key --init
    pacman-key --populate archlinuxarm
}

# Chroot commands to run after package operations
post_install() {
    locale-gen
    if [[ "${GENSSH:-false}" == "true" ]]; then
        systemctl enable sshd
    fi
}

# Files to remove from boot after kernel swap
boot_cleanup=("boot.scr" "boot.txt" "mkscr")

# Host-side hook — user creation
post_build() {
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

