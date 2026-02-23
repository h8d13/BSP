# shellcheck disable=SC2034,SC2148
pkgname=BootShimPorts
pkgver=0.1.0
pkgrel=1
pkgdesc='Host dependencies for building Arch Linux ARM images in Docker'
arch=('x86_64')
license=('GPL-3.0-or-later')
depends=(
    'just'
    'arch-install-scripts'
    'e2fsprogs'                 # e2fsck, resize2fs (flash)
    'parted'
    'xz'                        # extract .img.xz
    'docker'                    
    'docker-compose'
    'qemu-user-static'          # Cross-arch userspace emulation
    'qemu-user-static-binfmt'   # binfmt_misc registration for transparent execution
)

package() {
    return 0
}
