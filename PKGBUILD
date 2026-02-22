pkgname=BootShim
pkgver=0.1.0
pkgrel=1
pkgdesc='Host dependencies for building Arch Linux ARM images in Docker'
arch=('x86_64')
license=('MIT')
depends=(
    'docker'
    'docker-compose'
    'qemu-user-static'          # ARM userspace emulation
    'qemu-user-static-binfmt'   # binfmt_misc registration for transparent execution
)

package() {
    return 0
}
