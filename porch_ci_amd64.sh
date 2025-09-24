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

bhyvectl --vm=${vm_name} --destroy

expect -c "\
  spawn /usr/sbin/bhyveload -c stdio -m 3g -d ${disk} ${vm_name}; \
  expect { eof };  exit [lindex [wait] 3]" \
  >/dev/null 2>/dev/null
expect -c "\
  spawn /usr/sbin/bhyve -c 2 -m 3g -H -P \
    -s 0,hostbridge \
    -s 1,lpc \
    -s 2,virtio-blk,${disk} \
    -s 3,virtio-9p,meta=${meta_dirout} \
    -s 4,ahci-hd,${top}/disk-cam \
    -s 5,virtio-blk,${top}/disk1 \
    -s 6,virtio-blk,${top}/disk2 \
    -s 7,virtio-blk,${top}/disk3 \
    -s 8,virtio-blk,${top}/disk4 \
    -s 9,virtio-blk,${top}/disk5 \
    -l com1,stdio ${vm_name}; \
  expect { eof };  exit [lindex [wait] 3]" \
  >/dev/null 2>/dev/null

bhyvectl --vm=${vm_name} --destroy
