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

# TODO query as much variable information from the running system as possible
FREEBSD_BRANCH=stable/14
PKGBASE_JAILNAME=pkgbase_stable14_beastie
BUILDER_HOSTNAME=poudriere.home.arpa
KERNCONF=GENERIC
ABI=FreeBSD:14:amd64
CPUTYPE=$(cc -v -x c -E -march=native /dev/null 2>&1 | sed -n 's/.*-target-cpu *\([^ ]*\).*/\1/p')
PKGBASE_REPO="/usr/local/poudriere/data/images/${PKGBASE_JAILNAME}-repo/$ABI/latest"
PORTS_REPO="/usr/local/poudriere/data/packages/${PKGBASE_JAILNAME}-default"
PKGBASE_REPO_NAME=PoudrierePkgbase
PORTS_REPO_NAME=PoudrierePorts

step1() {
    # 1) install required packages from upstream mirror
    pkg install -y git poudriere ccache

    # 2) setup poudriere
    sed \
    	-e "s/.*BUILDER_HOSTNAME=.*/BUILDER_HOSTNAME=${BUILDER_HOSTNAME}/" \
    	-e 's/.*ALLOW_MAKE_JOBS_PACKAGES=.*/ALLOW_MAKE_JOBS_PACKAGES="pkg ccache rust* llvm* gcc* py* cmake* ghc*"/' \
    	-e 's/.*BAD_PKGNAME_DEPS_ARE_FATAL=.*/BAD_PKGNAME_DEPS_ARE_FATAL=yes/' \
    	-e 's%.*CCACHE_DIR=.*%CCACHE_DIR=/var/cache/ccache%' \
    	-e 's/.*NOLINUX=.*/NOLINUX=yes/' \
    	-e 's/.*PRIORITY_BOOST=.*/PRIORITY_BOOST="rust* llvm* gcc* py* cmake* ghc*"/' \
    	-e 's/.*TMPFS_BLACKLIST=.*/TMPFS_BLACKLIST="ghc* llvm* rust*"/' \
    	-e 's%.*TMPFS_BLACKLIST_TMPDIR=.*%TMPFS_BLACKLIST_TMPDIR="${BASEFS}/data/cache/tmp"%' \
    	-e 's/.*WRKDIR_ARCHIVE_FORMAT=.*/WRKDIR_ARCHIVE_FORMAT=tzst/' \
    	-e 's/.*ZPOOL=.*/ZPOOL=zroot/' \
    	/usr/local/etc/poudriere.conf.sample > /usr/local/etc/poudriere.conf

    git clone --depth 1 --branch "$FREEBSD_BRANCH" https://git.freebsd.org/src.git /usr/src
    echo "CPUTYPE?=$CPUTYPE" > /etc/make.conf
    echo "WITH_DIRDEPS_BUILD=1" > /etc/src-env.conf
    # TODO trim all src.conf tunables for a more minimal system
    cat <<EOF > /etc/src.conf
WITH_REPRODUCIBLE_BUILD=1
WITH_CCACHE_BUILD=1
WITHOUT_LLVM_TARGET_ALL=1
EOF

    sysrc kld_list+=filemon
    kldload filemon

    # 3) build system pkgbase
    poudriere jail -c -j "$PKGBASE_JAILNAME" -B -b -m src=/usr/src -K "$KERNCONF"

    # 4) convert system into a pkgbase installation

    mkdir -p /usr/local/etc/pkg/repos

    # TODO handle signatures
    cat <<EOF > /usr/local/etc/pkg/repos/poudriere_pkgbase.conf
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

    poudriere options -j "$PKGBASE_JAILNAME" -f "pkglist.txt"
    poudriere bulk -j "$PKGBASE_JAILNAME" -f "pkglist.txt"

    # 7) reinstall all system pkgs with the new poudriere repo
    cat <<EOF > /usr/local/etc/pkg/repos/poudriere_ports.conf
PoudrierePorts: {
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
