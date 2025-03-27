# TODO do a final grep to ensure that no files contain
# any templating artifacts like %%EMPT_XXX%%
_host_specific_setup() {
  # environment:
  : ${EMPT_ORG_DOMAIN:=empt.test}

  echo '$6$lNfYRw2DzRqbPccf$gH0wn2hv64/QIPtNDRazNok7IdySenCyhYFTUyyZoRXkABvhJnpeUdYSX2PMguUfCvVQ0hTsbDOo5Nd45Ki010' | \
    doas pw -R "${_worlddir}" usermod root -H 0
  doas pw -R "${_worlddir}" useradd mlmmj -c 'mlmmj manager' -d /var/spool/mlmmj -s /usr/sbin/nologin -h -
  sysrc -f "${_worlddir}/etc/rc.conf.local" hostname="it.${EMPT_ORG_DOMAIN}"

  sed -i'' \
    -e "s,%%EMPT_ORG_DOMAIN%%,${EMPT_ORG_DOMAIN},g" \
    "${_worlddir}/usr/local/etc/smb4.conf"
}
