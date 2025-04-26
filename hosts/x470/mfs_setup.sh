_host_specific_setup() {
  # set root and siva passwords
  echo '$6$08uINbEFl9EsRCzR$xokWgZnmzYW9Jyf3bqaq.TE.vbBZK8RBu50aKyLsGmeBxL63cShRbaoiBDJjEbOaFfZ4W.tvy/pdes9DbOKnC1' | \
      doas pw -R "${_worlddir}" usermod root -H 0
  echo '$6$602qzC8bCbJebi3L$5xf2vXluEZmZOx7a.aJ5/NzyAyurl6wC1ZTpvYB76QeAabWFPBICyl4TAa8UZ86x8tAfl2prc2992U1enWgCM0' | \
      doas pw -R "${_worlddir}" useradd -n siva -c "Siva Mahadevan" -G wheel -H 0
  grep '^\s*\w' "${ports_pkglist}" | xargs ${_pkg_cmd} install -y -r ports
  # TODO remove after this fix gets merged upstream
  doas sed -e 's,${pkg_bin} update -f;,${pkg_bin} update -f -r FreeBSD;,' -i '' "${_worlddir}/usr/local/share/poudriere/common.sh"
}
