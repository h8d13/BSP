# BS: BootShimPorts - mkimg
---

> A stage one Arch Linux image builder.

---

## Requirements

Install host dependencies (Arch Linux):

```bash
makepkg -si
```

This pulls in `docker`, `docker-compose`, `qemu-user-static`, and `qemu-user-static-binfmt`.

Then enable Docker:

```bash
sudo systemctl enable --now docker.service
sudo usermod -aG docker $USER
# Log out and back in for the group change to take effect
# Or $ newgrp docker 
```

## Usage

### Build

```bash
docker compose build
docker compose run builder rpi5
```

One liner: `docker compose build && docker compose run builder rpi5`

Output lands in `out/` as a compressed `.img.xz`.

### Clean

```bash
docker compose down
rm -f out/*.img.xz
```

`.tmp/` is cleaned up automatically on successful builds.

### Rebuild the Docker image

```bash
docker compose build --no-cache
```

### Flash

```bash
xz -d < out/archlinuxarm-rpi5-*.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
```

Replace `/dev/sdX` with your target device. CAREFUL WITH THIS.

## Configuration

Profiles live under `configs/<name>/`. Pass the profile name as an argument:

```bash
docker compose run builder <profile>
```

A profile directory contains:

```
configs/rpi5/
  profiledef.sh          # Main profile definition
  pacman.conf            # Pacman config installed into the image
  airootfs/              # Filesystem overlay copied onto the rootfs
    boot/
      config.txt         # Static boot config
      cmdline.txt.tpl    # Template — %ROOT_PARTUUID% gets stamped at build time
    etc/
      fstab.tpl          # Template — PARTUUIDs stamped at build time
      locale.conf
      locale.gen
      vconsole.conf
      systemd/
        network/          # networkd configs
        system/           # systemd unit symlinks (enable services)
```

### profiledef.sh

The main build configuration. Sourced as bash:

| Variable | Description |
|---|---|
| `device_name` | Human-readable device name |
| `arch` | Target architecture (e.g. `aarch64`) |
| `img_size` | Image size (e.g. `4G`) |
| `partition_table` | Partition table type (`msdos` or `gpt`) |
| `partitions` | Array of `"type size label"` specs (e.g. `"fat32 512M boot"`, `"ext4 rest root"`) |
| `tarball` | Path to the base rootfs tarball |
| `packages_remove` | Packages to remove in chroot |
| `packages_install` | Packages to install in chroot |
| `boot_cleanup` | Files to remove from `/boot` after package operations |
| `generate_ssh_keys` | Set to `true` to generate SSH host keys |
| `compression_opts` | Options passed to xz (e.g. `("-T0" "--best")`) |

Optional hooks (bash functions):

| Function | When |
|---|---|
| `pre_install()` | Before package operations (e.g. `pacman-key --init`) |
| `post_install()` | After package operations (e.g. `locale-gen`) |

### airootfs/

Files here are copied directly onto the root filesystem. Directory structure mirrors the target — `airootfs/etc/fstab.tpl` becomes `/etc/fstab.tpl` in the image.

Files ending in `.tpl` are templates. The builder replaces these variables and removes the `.tpl` extension:

| Variable | Value |
|---|---|
| `%BOOT_PARTUUID%` | PARTUUID of the boot partition |
| `%ROOT_PARTUUID%` | PARTUUID of the root partition |
| `%DATE%` | Build date (YYYY-MM-DD) |

### Adding a new profile

```bash
cp -r configs/rpi5 configs/mydevice
# Edit configs/mydevice/profiledef.sh and airootfs/ as needed
docker compose run builder mydevice
```
