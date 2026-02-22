FROM archlinux:latest

# Install build dependencies required by mkimg
# Core tools
RUN pacman -Syu --noconfirm --needed \
        arch-install-scripts \
        libarchive \
        openssh \
        parted \
        util-linux \
        xz \
        # Filesystem tools (default profile: fat32 + ext4)
        dosfstools \
        e2fsprogs \
        # Uncomment for additional filesystem support:
        # btrfs-progs \
        # xfsprogs \
        # f2fs-tools \
    && pacman -Scc --noconfirm

WORKDIR /build

ENTRYPOINT ["/build/build"]
