#!/bin/sh

set -x
outdir="$1"
test_filters="$2"
vm_name="$(basename ${outdir})"
disk="${outdir}/disk.raw"

meta_tar="${outdir}/test-reports.tar"
meta_dir="${outdir}/test-reports.d"
meta_dirout="${outdir}/test-reports"

mkdir -p "${meta_dir}" "${meta_dirout}"
truncate -s 512M "${meta_tar}"
tar rvf "${meta_tar}" -C "${meta_dir}" .

truncate -s 128m \
  "${outdir}/disk1" \
  "${outdir}/disk2" \
  "${outdir}/disk3" \
  "${outdir}/disk4" \
  "${outdir}/disk5" \
  "${outdir}/disk-cam"

bhyvectl --vm=${vm_name} --destroy || true
expect -c "spawn /usr/sbin/bhyveload -c stdio -m 4g -d ${disk} ${vm_name};  expect { eof };  exit [lindex [wait] 3]"
(
cat <<EOF
local argv = {}
local cmd = "/usr/sbin/bhyve -c 2 -m 4g -A -H -P \z
  -s 0:0,hostbridge \z
  -s 1:0,lpc \z
  -s 2:0,virtio-blk,${disk} \z
  -s 3:0,virtio-blk,${meta_tar} \z
  -s 4:0,ahci-hd,${outdir}/disk-cam \z
  -s 5:0,virtio-blk,${outdir}/disk1 \z
  -s 6:0,virtio-blk,${outdir}/disk2 \z
  -s 7:0,virtio-blk,${outdir}/disk3 \z
  -s 8:0,virtio-blk,${outdir}/disk4 \z
  -s 9:0,virtio-blk,${outdir}/disk5 \z
  -l com1,stdio ${vm_name}"
for arg in cmd:gmatch("%S+") do
  table.insert(argv, arg)
end
spawn(argv)

log("/dev/stdout")
timeout(60*60*2)

match "login:"
write("root\\r")

match("root@.*#")
write("sysrc freebsdci_test_filters='${test_filters}'\\r")

match("root@.*#")
write("service freebsdci onestart\\r")

eof()
EOF
) | porch

bhyvectl --vm=${vm_name} --destroy || true

tar xfv ${meta_tar} -C ${meta_dirout}
rm -rf ${meta_tar} ${meta_dir}
chmod 0755 ${meta_dirout}
echo "Extracted kyua reports to ${meta_dirout}"
