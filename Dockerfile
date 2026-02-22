FROM archlinux:latest

# Install build dependencies required by mkimg
# Additional filesystem support if needed: btrfs-progs, xfsprogs, f2fs-tools
RUN pacman -Syu --noconfirm --needed \
        arch-install-scripts \
        libarchive \
        openssh \
        parted \
        util-linux \
        xz \
        dosfstools \
        e2fsprogs \
        grub \
    && pacman -Scc --noconfirm

WORKDIR /build

ENTRYPOINT ["/build/build"]
