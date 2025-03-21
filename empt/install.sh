#!/bin/sh

set -eu

while getopts d:v: name
do
  case "${name}" in
    d) org_domain="${OPTARG}" ;;
    v) vdev="${OPTARG}" ;;
    ?)
      echo "Usage: $0 -d <org domain name> -v <vdev for installation>" >&2
      exit 64 # EX_USAGE
      ;;
    *) ;;
  esac
done
shift $((OPTIND - 1))

##### SETUP PARTITIONS #####

gpart destroy -F "${vdev}"
gpart create -s GPT "${vdev}"

gpart add -a 4k -l empt_efiboot -t efi -s 260m "${vdev}"
newfs_msdos /dev/gpt/empt_efiboot

gpart add -a 4k -l empt_gptzfsboot -t freebsd-boot -s 512k "${vdev}"
gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 2 "${vdev}"

gpart add -a 1m -l empt_swap -t freebsd-swap -s 2g "${vdev}"

gpart add -a 1m -l empt_zfs -t freebsd-zfs "${vdev}"
zpool labelclear -f /dev/gpt/empt_zfs || true

##### POPULATE ZPOOL #####

mkdir -p /mnt/empt

# FreeBSD zfs system hierarchy
zpool create -f \
  -o autoexpand=on \
  -O canmount=noauto \
  -O atime=off \
  -R /mnt/empt zroot /dev/gpt/empt_zfs
zfs create -o mountpoint=none                             zroot/ROOT
zfs create -o mountpoint=/                                zroot/ROOT/default
zfs create -o mountpoint=/var -o canmount=off             zroot/var
zfs create -o setuid=off -o exec=off                      zroot/var/audit
zfs create -o setuid=off -o exec=off                      zroot/var/crash
zfs create -o setuid=off -o exec=off -o compression=zstd  zroot/var/log
zfs create -o setuid=off                                  zroot/var/tmp
zfs create -o atime=on -o compression=zstd                zroot/var/mail

# EMPT hierarchy
zfs create \
  -o setuid=off \
  -o exec=off \
  -o mountpoint=/empt \
  zroot/empt
zfs create zroot/empt/homes
zfs create zroot/empt/groups
zfs create zroot/empt/sojudb

zpool set bootfs=zroot/ROOT/default zroot

##### INSTALL WORLD #####

cat > /tmp/repos.conf <<EOF
pkgbase: {
  url: "file://${PWD}/repos/pkgbase",
  enabled: yes
}
ports: {
  url: "file://${PWD}/repos/ports",
  enabled: yes
}
EOF
_pkg_cmd="env ABI=FreeBSD:15:amd64 pkg -o REPOS_DIR=/tmp -o ASSUME_ALWAYS_YES=yes -r /mnt/empt"
${_pkg_cmd} install -y -r pkgbase -g 'FreeBSD-*'
grep '^\s*\w' pkglist.txt | xargs ${_pkg_cmd} install -y -r ports

# Copy the bootloader to the EFI partition
mkdir -p /mnt/empt/boot/efi
mount -t msdosfs /dev/gpt/empt_efiboot /mnt/empt/boot/efi

mkdir -p /mnt/empt/boot/efi/efi/boot /mnt/empt/boot/efi/efi/freebsd
cp /mnt/empt/boot/loader.efi /mnt/empt/boot/efi/efi/boot/bootx64.efi
cp /mnt/empt/boot/loader.efi /mnt/empt/boot/efi/efi/freebsd/loader.efi

# Delete all pre-existing FreeBSD EFI entries
efibootmgr | grep 'FreeBSD.*$' | sed 's/.*Boot\([[:digit:]]*\).*/\1/g' | xargs -L1 efibootmgr -B -b
# Create a new one for EMPT's FreeBSD install
efibootmgr --create --activate --label FreeBSD-EMPT --loader '/mnt/empt/boot/efi/efi/freebsd/loader.efi'

umount /mnt/empt/boot/efi

##### SETUP EMPT INSIDE CHROOT #####

# copy world overlay and run custom configuration script
cp -R common_overlay/ /mnt/empt/
chroot /mnt/empt /bin/sh <<EOF

# Setup ACME for automatic TLS cert renewal
# TODO setup acme with katcheri.org once everything else is done
# TODO replace with production once working
#acme.sh --home /var/db/acme --set-default-ca --server letsencrypt_test
#acme.sh --home /var/db/acme --issue --standalone -d 'empt.${org_domain}'
#acme.sh --install-cert -d example.com \
#  --fullchain-file /etc/ssl/empt.${org_domain}.crt.pem \
#  --key-file       /etc/ssl/empt.${org_domain}.key.pem  \
#  --reloadcmd     'service nginx force-reload'

# TODO setup NFS
# Set permissions on the EMPT hierarchy
# TODO tighten up permissions

install -d -o root -g wheel -m 1755 /empt/groups
install -d -o soju -g soju -m 0755 /empt/sojudb

EOF
