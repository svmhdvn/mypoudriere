#!/bin/sh

# NOTES:
# Must run with the following conditions:
# * as root
# * on a freshly-installed FreeBSD 14.0-RELEASE system
#
# REQUIRED PKGS BEFORE BOOTSTRAP:
# * doas (configured with 'permit nopass :wheel')

# TODO query as much variable information from the running system as possible
FREEBSD_BRANCH=stable/14
PKGBASE_JAILNAME=pkgbase-stable14
BUILDER_HOSTNAME=poudriere.home.arpa
KERNCONF=GENERIC
ABI=FreeBSD:14:amd64
CPUTYPE=$(cc -v -x c -E -march=native /dev/null 2>&1 | sed -n 's/.*-target-cpu *\([^ ]*\).*/\1/p')

set -ex

step1() {
    # 1) install required packages from upstream mirror

    pkg install -y git poudriere ccache

    # 2) setup poudriere

    sed \
    	-e "/BUILDER_HOSTNAME=/c\BUILDER_HOSTNAME=$BUILDER_HOSTNAME" \
    	-e '/ALLOW_MAKE_JOBS_PACKAGES=/c\ALLOW_MAKE_JOBS_PACKAGES="pkg ccache py* gcc* ghc* llvm* rust*"' \
    	-e '/BAD_PKGNAME_DEPS_ARE_FATAL=/c\BAD_PKGNAME_DEPS_ARE_FATAL=yes' \
    	-e '/CCACHE_DIR=/c\CCACHE_DIR=/var/cache/ccache' \
    	-e '/NOLINUX=/c\NOLINUX=yes' \
    	-e '/PRIORITY_BOOST=/c\PRIORITY_BOOST="py* gcc* ghc* llvm* rust*"' \
    	-e '/TMPFS_BLACKLIST=/c\TMPFS_BLACKLIST="gcc* ghc* llvm* rust*"' \
    	-e '/WRKDIR_ARCHIVE_FORMAT=/c\WRKDIR_ARCHIVE_FORMAT=tzst' \
    	-e '/ZPOOL=/c\ZPOOL=zroot' \
    	/usr/local/etc/poudriere.conf.sample > /usr/local/etc/poudriere.conf

    git clone --depth 1 --branch "$FREEBSD_BRANCH" git.freebsd.org/src.git /usr/src
    echo "CPUTYPE?=$CPUTYPE" > /etc/make.conf
    echo "WITH_DIRDEPS_BUILD=1" > /etc/src-env.conf
    # TODO trim all src.conf tunables for a more minimal system
    cat <<EOF > /etc/src.conf
WITHOUT_CLEAN=1
WITH_REPRODUCIBLE_BUILD=1
WITH_CCACHE_BUILD=1
WITHOUT_LLVM_TARGET_ALL=1
EOF

    # 3) build system pkgbase
    poudriere jail -c -j "$PKGBASE_JAILNAME" -B -b -m src=/usr/src -K "$KERNCONF"

    # 4) convert system into a pkgbase installation

    mkdir -p /usr/local/etc/pkg/repos

    # TODO handle signatures
    cat <<EOF > /usr/local/etc/pkg/repos/base.conf
pkgbase: {
  url: "file:///usr/local/poudriere/data/images/$ABI/latest",
  enabled: yes
}
EOF

    pkg install -y -r pkgbase -g 'FreeBSD-*'

    # TODO find a cleaner way to do this
    # Instructions from https://wiki.freebsd.org/PkgBase
    cp /etc/master.passwd.pkgsave /etc/master.passwd
    cp /etc/group.pkgsave /etc/group
    pwd_mkdb -p /etc/master.passwd
    cp /etc/sysctl.conf.pkgsave /etc/sysctl.conf
    find / -name '*.pkgsave' -delete
    rm /boot/kernel/linker.hints
    reboot
}

step2() {
    true
}
