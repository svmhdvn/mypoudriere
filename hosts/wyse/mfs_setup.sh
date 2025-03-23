_host_specific_setup() {
  #echo '$6$Zkev60CweKRVaFcr$lMpMUp06d.10Vdg9iuM3qzCVZa1dBoyAwxD6TRRPpxsShl4dU8/uzdzB50N9PRv34QoTlvTcKou//pPuqcU6W0' | \
  #  doas pw -R "${_worlddir}" usermod root -H 0
  doas cp -R "${top}/empt" "${_worlddir}/empt"

  doas mkdir -p \
    "${_worlddir}/home" \
    "${_worlddir}/media/mfs" \
    "${_worlddir}/mnt" \
    "${_worlddir}/root" \
    "${_worlddir}/empt/repos"

  doas cp -R "${host_pkgbase_repo}/" "${_worlddir}/empt/repos/pkgbase"
  doas cp -R "${ports_repo}/" "${_worlddir}/empt/repos/ports"
  doas cp "${ports_pkglist}" "${_worlddir}/empt/pkglist.txt"
}
