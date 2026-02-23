# shellcheck disable=SC2034,SC2148
pkgname=BootShimPorts
pkgver=0.1.0
pkgrel=1
pkgdesc='Host dependencies for building Arch Linux ARM images in Docker'
arch=('x86_64')
license=('MIT')
depends=(
    'just'
    'arch-install-scripts'
    'parted'
    'docker'
    'docker-compose'
    'qemu-user-static'          # Cross-arch userspace emulation
    'qemu-user-static-binfmt'   # binfmt_misc registration for transparent execution
)

package() {
    return 0
}
