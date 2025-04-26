# TODO do a final grep to ensure that no files contain
# any templating artifacts like %%EMPT_XXX%%
_host_specific_setup() {
  # environment:
  : ${EMPT_ORG_DOMAIN:=empt.test}
  EMPT_REALM="$(echo "${EMPT_ORG_DOMAIN}" | tr '[:lower:]' '[:upper:]')"

  echo '$6$lNfYRw2DzRqbPccf$gH0wn2hv64/QIPtNDRazNok7IdySenCyhYFTUyyZoRXkABvhJnpeUdYSX2PMguUfCvVQ0hTsbDOo5Nd45Ki010' | \
    doas pw -R "${_worlddir}" usermod root -H 0
  doas pw -R "${_worlddir}" useradd mlmmj -c 'mlmmj manager' -d /var/spool/mlmmj -s /usr/sbin/nologin -h -

  grep -R '%%[^%]*%%' -l "${_worlddir}" | xargs sed \
    -e "s,%%EMPT_ORG_DOMAIN%%,${EMPT_ORG_DOMAIN},g" \
    -e "s,%%EMPT_REALM%%,${EMPT_REALM},g" \
    -i ''
}
