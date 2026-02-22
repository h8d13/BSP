# stage-one-builder

Build ready-to-flash Arch Linux images for any device in minutes.

## Requirements

```bash
makepkg -si                          # pulls docker, qemu-user-static, etc.
sudo systemctl enable --now docker
sudo usermod -aG docker $USER        # log out/in after or nwgroup docker
```

## Quick start

```bash
docker compose build
docker compose run --rm buildit g5-ppc64
./extract archlinux-g5-ppc64-20260222
sudo ./flash archlinux-g5-ppc64-20260222 /dev/sdX
```

## Available profiles

| Profile | Device | Arch | Boot method |
|---|---|---|---|
| `rpi5` | Raspberry Pi 5 | aarch64 | config.txt |
| `g5-ppc64` | PowerMac G5 | ppc64 | Open Firmware (`boot ud:2,\grub`) |

## Scripts

| Script | Usage |
|---|---|
| `build <profile>` | Build an image (wraps docker compose) |
| `extract <image>` | Decompress `.img.xz` from `out/` to `out_extract/` with progress |
| `flash <image> <device>` | Write extracted image to block device with confirmation |

## Personal credentials

Create `personal-creds.conf` (gitignored) to set a default user:

```bash
USERNAME=hadean
PASSWORD=changeme
```

The build creates the user in the `wheel` group with sudo access. Without this file, root gets an empty password.

## Profile structure

```
configs/<name>/
  profiledef.sh        # Build config: partitions, packages, hooks
  pacman.conf          # Installed into the image
  airootfs/            # Filesystem overlay (mirrors target /)
    etc/
      fstab.tpl        # Template — %ROOT_UUID% stamped at build time
      mkinitcpio.conf  # initramfs config
      ...
```

### profiledef.sh variables

| Variable | Example |
|---|---|
| `device_name` | `"PowerMac G5"` |
| `arch` | `ppc64`, `aarch64` |
| `img_size` | `2G` |
| `partition_table` | `mac`, `msdos`, `gpt` |
| `partitions` | `("hfs 32M bootstrap" "ext4 rest root")` |
| `tarball` | Path to base rootfs `.tar.gz` |
| `packages_install` | `("base" "linux-ppc64" "grub" ...)` |
| `packages_remove` | Packages to remove in chroot |
| `compression_opts` | `("-T0" "-6")` |
| `generate_ssh_keys` | `true` |

### Hooks

| Function | Runs | Example |
|---|---|---|
| `pre_install()` | In chroot, before packages | `pacman-key --init` |
| `post_install()` | In chroot, after packages | `grub-mkconfig`, `locale-gen` |
| `post_build()` | On host, image still mounted | Bootloader install, user creation |

### Template variables

Files ending in `.tpl` get these replaced, then `.tpl` is stripped:

`%ROOT_UUID%`, `%ROOT_PARTUUID%`, `%BOOT_UUID%`, `%BOOT_PARTUUID%`, `%BOOTSTRAP_UUID%`, `%BOOTSTRAP_PARTUUID%`, `%DATE%`

## Clean

```bash
docker compose down
rm -f out/*.img.xz out_extract/*.img
```
