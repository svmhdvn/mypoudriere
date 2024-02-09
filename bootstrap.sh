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

HOSTNAME="$(hostname)"
JAILNAME="poudriere_stable${FREEBSD_VERSION}_upstream"
BUILDER_HOSTNAME=poudriere.home.arpa
# TODO change for custom kernel config
KERNCONF=GENERIC
#CPUTYPE=$(cc -v -x c -E -march=native /dev/null 2>&1 | sed -n 's/.*-target-cpu *\([^ ]*\).*/\1/p')

PKGBASE_REPO="/usr/local/poudriere/data/images/${JAILNAME}-repo/FreeBSD:${FREEBSD_VERSION}:amd64/latest"
PKGBASE_REPO_NAME=PoudrierePkgbase

PORTS_REPO="/usr/local/poudriere/data/packages/${JAILNAME}-default-${HOSTNAME}"
PORTS_REPO_NAME=PoudrierePorts

step1() {
    # 1) install required packages from upstream mirror
    pkg install -y git poudriere ccache

    # 2) setup poudriere
    # TODO change ccache directory to a better global location, possibly /var/cache/ccache
    # NOTE add back if needed to the sed command:
#    	-e 's/.*TMPFS_BLACKLIST=.*/TMPFS_BLACKLIST="ghc* llvm* rust*"/' \
#    	-e 's%.*TMPFS_BLACKLIST_TMPDIR=.*%TMPFS_BLACKLIST_TMPDIR="${BASEFS}/data/cache/tmp"%' \
    sed \
    	-e "s/.*BUILDER_HOSTNAME=.*/BUILDER_HOSTNAME=${BUILDER_HOSTNAME}/" \
    	-e 's/.*ALLOW_MAKE_JOBS_PACKAGES=.*/ALLOW_MAKE_JOBS_PACKAGES="pkg ccache rust* llvm* gcc* python* cmake*"/' \
    	-e 's/.*BAD_PKGNAME_DEPS_ARE_FATAL=.*/BAD_PKGNAME_DEPS_ARE_FATAL=yes/' \
    	-e 's%.*CCACHE_DIR=.*%CCACHE_DIR=/root/.ccache%' \
    	-e 's/.*NOLINUX=.*/NOLINUX=yes/' \
    	-e 's/.*WRKDIR_ARCHIVE_FORMAT=.*/WRKDIR_ARCHIVE_FORMAT=tzst/' \
    	-e 's/.*ZPOOL=.*/ZPOOL=zroot/' \
    	/usr/local/etc/poudriere.conf.sample > /usr/local/etc/poudriere.conf

    cp \
    	"${HOSTNAME}-make.conf" \
    	"${HOSTNAME}-src.conf" \
    	"${HOSTNAME}-src-env.conf" \
    	"/usr/local/etc/poudriere.d/"

    sysrc kld_list+=filemon
    kldload -n filemon

    # 3) build system pkgbase

    # TODO move to -m src=/usr/src once upstream Poudriere maintains file modification times
    # for better incremental builds using WITH_META_MODE
    #if test ! -d /usr/src/.git; then
        #git clone --depth 1 --branch "stable/${FREEBSD_VERSION}" https://git.freebsd.org/src.git /usr/src
    #fi
    #git -C /usr/src pull
    #poudriere jail -c -j "$JAILNAME" -b -m src=/usr/src -B -K "$KERNCONF" -z "$HOSTNAME"

    poudriere jail -c -j "$JAILNAME" -b -m git+https -v "stable/$FREEBSD_VERSION" -B -K "$KERNCONF" -z "$HOSTNAME"

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
    fi

    mkdir -p /usr/ports/distfiles
    git -C /usr/ports pull

    poudriere options -j "$JAILNAME" -z "$HOSTNAME" -f "pkglist.txt"
    poudriere bulk -j "$JAILNAME" -z "$HOSTNAME" -f "pkglist.txt"

    # 7) reinstall all system pkgs with the new poudriere repo
    cat <<EOF > /usr/local/etc/pkg/repos/poudriere_ports.conf
${PORTS_REPO_NAME}: {
  url: "file://$PORTS_REPO"
  enabled: yes
}
EOF

    cat <<EOF > /usr/local/etc/pkg/repos/FreeBSD.conf
FreeBSD: {
  url: "pkg+https://pkg.freebsd.org/$${ABI}/latest",
  mirror_type: "srv",
  signature_type: "fingerprints",
  fingerprints: "/usr/share/keys/pkg",
  enabled: "no"
}
EOF
    pkg upgrade -y
}

case $1 in
    step1) step1;;
    step2) step2;;
    *) echo "unknown step $1" >&2; exit 1;
esac
