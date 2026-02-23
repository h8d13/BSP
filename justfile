# BootShim Ports — BSP
# Build ready-to-flash Arch Linux images for any device

set dotenv-load := false

# Default profile
profile := "g5-ppc64"

# Datestamp for image names
date := `date +%Y%m%d`

# Derived image name
image := "archlinux-" + profile + "-" + date

# ── Setup ────────────────────────────────────────────────────────────────────

# Install host dependencies and enable docker
setup:
    makepkg -si
    sudo systemctl enable --now docker
    @echo "Add yourself to the docker group if needed: sudo usermod -aG docker \$USER"

# Build the Docker builder image
docker-build:
    mkdir -p in out out_extract .tmp
    docker compose build

# ── Build ────────────────────────────────────────────────────────────────────

# Build an image for a profile (default: g5-ppc64)
buildit profile=profile: docker-build
    mkdir -p in out out_extract .tmp
    docker compose run --rm buildit -p /build/configs/{{profile}} -o /build/out

# Bootstrap a rootfs tarball from scratch (requires qemu-user-static-binfmt)
bootstrap profile=profile:
    sudo ./bootstrap/bootstrap {{profile}}

# ── Post-build ───────────────────────────────────────────────────────────────

# Decompress .img.gz/.img.xz to out_extract/
extract image=image:
    mkdir -p out_extract
    ./extract {{image}}

# Write extracted image to a block device
flash image=image device="":
    @test -n "{{device}}" || { echo "Usage: just flash <image> <device>"; exit 1; }
    sudo ./flash {{image}} {{device}}

# ── Clean ────────────────────────────────────────────────────────────────────

# Remove built images
clean:
    sudo rm -f out/*.img.gz out/*.img.xz out_extract/*.img

# Full clean — images + docker + orphaned containers
clean-all: clean
    docker compose down --remove-orphans

# ── Info ─────────────────────────────────────────────────────────────────────

# List available profiles
profiles:
    @ls configs/

# List built images
images:
    @echo "Compressed (out/):"
    @ls -lh out/*.img.gz out/*.img.xz 2>/dev/null || echo "  (none)"
    @echo ""
    @echo "Extracted (out_extract/):"
    @ls -lh out_extract/*.img 2>/dev/null || echo "  (none)"

# Show available recipes
default:
    @just --list
