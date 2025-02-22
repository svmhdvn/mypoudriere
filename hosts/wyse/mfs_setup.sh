_host_specific_setup() {
  echo '$6$08uINbEFl9EsRCzR$xokWgZnmzYW9Jyf3bqaq.TE.vbBZK8RBu50aKyLsGmeBxL63cShRbaoiBDJjEbOaFfZ4W.tvy/pdes9DbOKnC1' | \
    doas pw -R "${_worlddir}" usermod root -H 0

  doas pkg -R "${_pkg_repos}" -r "${_worlddir}" install -y -r ports dhcpcd
  for j in dns kerberos mail irc cifs www; do
    doas mkdir -p "${_worlddir}/jails/${j}"
    doas pkg -R "${_pkg_repos}" -r "${_worlddir}/jails/${j}" install -y -r jail_pkgbase -g 'FreeBSD-*' &
  done
  wait
}
