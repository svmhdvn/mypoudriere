#!/bin/sh

realpath="$(realpath "$0")"
top="$(dirname "${realpath}")"
vm_name="$(basename ${top})"
disk="/dev/zvol/zroot/sivabhyve/${vm_name}"
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

expect -c "\
  spawn /usr/sbin/bhyve -c 2 -m 4g \
    -s 0,hostbridge \
    -s 1,virtio-blk,${disk} \
    -s 2,virtio-9p,meta=${meta_dirout} \
    -s 3,ahci-hd,${top}/disk-cam \
    -s 4,virtio-blk,${top}/disk1 \
    -s 5,virtio-blk,${top}/disk2 \
    -s 6,virtio-blk,${top}/disk3 \
    -s 7,virtio-blk,${top}/disk4 \
    -s 8,virtio-blk,${top}/disk5 \
    -o console=stdio \
    -o bootrom=/usr/local/share/u-boot/u-boot-bhyve-arm64/u-boot.bin \
    ${vm_name}; \
  expect { eof };  exit [lindex [wait] 3]" \
  >/dev/null 2>/dev/null

bhyvectl --vm=${vm_name} --destroy || true
