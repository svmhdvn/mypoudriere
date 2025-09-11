#!/bin/sh

set -x

realpath="$(realpath "$0")"
top="$(dirname "${realpath}")"
vm_name="$(basename ${top})"

disk="${top}/disk.raw"

meta_tar="${top}/test-reports.tar"
meta_dir="${top}/test-reports.d"
meta_dirout="${top}/test-reports"

mkdir -p "${meta_dir}" "${meta_dirout}"
truncate -s 512M "${meta_tar}"
cp "${top}/kyua_filters.txt" "${meta_dir}"
tar rvf "${meta_tar}" -C "${meta_dir}" .

truncate -s 128m \
  "${top}/disk1" \
  "${top}/disk2" \
  "${top}/disk3" \
  "${top}/disk4" \
  "${top}/disk5" \
  "${top}/disk-cam"

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
  -s 4:0,ahci-hd,${top}/disk-cam \z
  -s 5:0,virtio-blk,${top}/disk1 \z
  -s 6:0,virtio-blk,${top}/disk2 \z
  -s 7:0,virtio-blk,${top}/disk3 \z
  -s 8:0,virtio-blk,${top}/disk4 \z
  -s 9:0,virtio-blk,${top}/disk5 \z
  -l com1,stdio ${vm_name}"
for arg in cmd:gmatch("%S+") do
  table.insert(argv, arg)
end
spawn(argv)

log("/dev/stdout")
timeout(60*60)

match "login:"
write("root\\r")

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
