#!/hint/bash
# Profile: Raspberry Pi 5 Model B
# Arch Linux ARM with linux-rpi kernel

device_name="Raspberry Pi 5 Model B"
arch="aarch64"

# Image layout
img_size="4G"
partition_table="msdos"
partitions=(
    "fat32  512M  boot"
    "ext4   rest  root"
)

# Source rootfs
tarball="${script_dir}/ArchLinuxARM-rpi-aarch64-latest.tar.gz"

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
}

# Files to remove from boot after kernel swap
boot_cleanup=("boot.scr" "boot.txt" "mkscr")

# SSH host key generation
generate_ssh_keys=true

# Output compression
compression="xz"
compression_opts=("-T0" "-6")
