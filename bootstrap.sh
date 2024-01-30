#!/bin/sh

# NOTES:
# Must run with the following conditions:
# * as root
# * on a freshly-installed FreeBSD 14.0-RELEASE system
# * inside the git repo
#
# REQUIRED PKGS BEFORE BOOTSTRAP:
# * doas (configured with 'permit nopass :wheel')

set -ex

FREEBSD_VERSION=14
ARCH=amd64

ABI="FreeBSD:${FREEBSD_VERSION}:${ARCH}"
JAILNAME="${ABI}_$(hostname)"
BUILDER_HOSTNAME=poudriere.home.arpa
# TODO change for custom kernel config
KERNCONF=GENERIC
CPUTYPE=$(cc -v -x c -E -march=native /dev/null 2>&1 | sed -n 's/.*-target-cpu *\([^ ]*\).*/\1/p')

PKGBASE_REPO="/usr/local/poudriere/data/images/${JAILNAME}-repo/$ABI/latest"
PKGBASE_REPO_NAME=PoudrierePkgbase

PORTS_REPO="/usr/local/poudriere/data/packages/${JAILNAME}-default"
PORTS_REPO_NAME=PoudrierePorts

step1() {
    # 1) install required packages from upstream mirror
    pkg install -y git poudriere ccache

    # 2) setup poudriere
    # NOTE add back if needed to the sed command:
#    	-e 's/.*TMPFS_BLACKLIST=.*/TMPFS_BLACKLIST="ghc* llvm* rust*"/' \
#    	-e 's%.*TMPFS_BLACKLIST_TMPDIR=.*%TMPFS_BLACKLIST_TMPDIR="${BASEFS}/data/cache/tmp"%' \
    sed \
    	-e "s/.*BUILDER_HOSTNAME=.*/BUILDER_HOSTNAME=${BUILDER_HOSTNAME}/" \
    	-e 's/.*ALLOW_MAKE_JOBS_PACKAGES=.*/ALLOW_MAKE_JOBS_PACKAGES="pkg ccache rust* llvm* gcc* py* cmake* ghc*"/' \
    	-e 's/.*BAD_PKGNAME_DEPS_ARE_FATAL=.*/BAD_PKGNAME_DEPS_ARE_FATAL=yes/' \
    	-e 's%.*CCACHE_DIR=.*%CCACHE_DIR=/var/cache/ccache%' \
    	-e 's/.*NOLINUX=.*/NOLINUX=yes/' \
    	-e 's/.*PRIORITY_BOOST=.*/PRIORITY_BOOST="pkg ccache cmake* rust* llvm* gcc* py* ghc*"/' \
    	-e 's/.*WRKDIR_ARCHIVE_FORMAT=.*/WRKDIR_ARCHIVE_FORMAT=tzst/' \
    	-e 's/.*ZPOOL=.*/ZPOOL=zroot/' \
    	/usr/local/etc/poudriere.conf.sample > /usr/local/etc/poudriere.conf

    git clone --depth 1 --branch "stable/${FREEBSD_VERSION}" https://git.freebsd.org/src.git /usr/src
    echo "CPUTYPE?=$CPUTYPE" > "/usr/local/etc/poudriere.d/$(hostname)-make.conf"
    echo "WITH_DIRDEPS_BUILD=1" > "/usr/local/etc/poudriere.d/$(hostname)-src-env.conf"
    # TODO trim all src.conf tunables for a more minimal system
    cat > "/usr/local/etc/poudriere.d/$(hostname)-src.conf" <<EOF
WITHOUT_CLEAN=1
WITH_REPRODUCIBLE_BUILD=1
WITH_CCACHE_BUILD=1
WITHOUT_LLVM_TARGET_ALL=1
EOF

    sysrc kld_list+=filemon
    kldload filemon

    # 3) build system pkgbase
    poudriere jail -c -j "$JAILNAME" -B -b -m src=/usr/src -K "$KERNCONF" -z "$(hostname)"

    # 4) convert system into a pkgbase installation

    mkdir -p /usr/local/etc/pkg/repos

    # TODO handle signatures
    cat > /usr/local/etc/pkg/repos/poudriere_pkgbase.conf <<EOF
${PKGBASE_REPO_NAME}: {
  url: "file://${PKGBASE_REPO}"
  enabled: yes
}
EOF

    pkg install -y -r "$PKGBASE_REPO_NAME" -g 'FreeBSD-*'

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
    if test ! -d /usr/ports/.git; then
        # 5) setup ports collection
        git clone --depth 1 https://git.freebsd.org/ports.git /usr/ports

        # 6) create poudriere ports pointer to the local ports collection
        poudriere ports -c -m null -M /usr/ports
        mkdir -p /usr/ports/distfiles
    fi

    poudriere options -j "$JAILNAME" -f "pkglist.txt"
    poudriere bulk -j "$JAILNAME" -f "pkglist.txt"

    # 7) reinstall all system pkgs with the new poudriere repo
    cat <<EOF > /usr/local/etc/pkg/repos/poudriere_ports.conf
${PORTS_REPO_NAME}: {
  url: "file://$PORTS_REPO"
  enabled: yes
}
EOF

    pkg upgrade -y
}

case $1 in
    step1) step1;;
    step2) step2;;
    *) echo "unknown step $1" >&2; exit 1;
esac
