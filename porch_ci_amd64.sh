#!/bin/sh

realpath="$(realpath "$0")"
top="$(dirname "${realpath}")"
vm_name="$(basename ${top})"
disk="/dev/zvol/zroot/bhyve/${vm_name}"
meta_dirout="${top}/test-reports"

rm -rf "${meta_dirout}"
mkdir -p "${meta_dirout}"
cp "${top}/kyua_test_filters.txt" "${meta_dirout}"

truncate -s 128m \
  "${top}/disk1" \
  "${top}/disk2" \
  "${top}/disk3" \
  "${top}/disk4" \
  "${top}/disk5" \
  "${top}/disk-cam"

bhyvectl --vm=${vm_name} --destroy || true
expect -c "spawn /usr/sbin/bhyveload -c stdio -m 4g -d ${disk} ${vm_name};  expect { eof };  exit [lindex [wait] 3]"

#log("/dev/stdout")
#timeout(60*60)
#match "login:"
#write("root\\r")
#match("root@.*#")
#write("service freebsdci onestart\\r")
(
cat <<EOF
local argv = {}
local cmd = "/usr/sbin/bhyve -c 2 -m 4g -H -P \z
  -s 0,hostbridge \z
  -s 1,lpc \z
  -s 2,virtio-blk,${disk} \z
  -s 3,virtio-9p,meta=${meta_dirout} \z
  -s 4,ahci-hd,${top}/disk-cam \z
  -s 5,virtio-blk,${top}/disk1 \z
  -s 6,virtio-blk,${top}/disk2 \z
  -s 7,virtio-blk,${top}/disk3 \z
  -s 8,virtio-blk,${top}/disk4 \z
  -s 9,virtio-blk,${top}/disk5 \z
  -l com1,stdio ${vm_name}"
for arg in cmd:gmatch("%S+") do
  table.insert(argv, arg)
end
spawn(argv)
timeout(60*60)
eof()
EOF
) | porch

bhyvectl --vm=${vm_name} --destroy || true
