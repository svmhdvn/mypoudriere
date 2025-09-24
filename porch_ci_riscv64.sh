#!/bin/sh

set -x

realpath="$(realpath "$0")"
top="$(dirname "${realpath}")"
vm_name="$(basename ${top})"
disk="/dev/zvol/zroot/bhyve/${vm_name}"

meta_tar="${top}/test-reports.tar"
meta_dir="${top}/test-reports.d"
meta_dirout="${top}/test-reports"

mkdir -p "${meta_dir}" "${meta_dirout}"
truncate -s 512M "${meta_tar}"
cp "${top}/kyua_filters.txt" "${meta_dir}"
tar rvf "${meta_tar}" -C "${meta_dir}" .

# TODO figure out QEMU_DEVICES
#truncate -s 128m \
#  "${top}/disk1" \
#  "${top}/disk2" \
#  "${top}/disk3" \
#  "${top}/disk4" \
#  "${top}/disk5" \
#  "${top}/disk-cam"

timeout -k 1m 1h /usr/local/bin/qemu-system-riscv64 \
  -machine virt \
  -smp 2 \
  -m 4g \
  -nographic \
  -no-reboot \
  -bios /usr/local/share/opensbi/lp64/generic/firmware/fw_jump.elf \
  -kernel /usr/local/share/u-boot/u-boot-qemu-riscv64/u-boot.bin \
  -device virtio-blk,drive=hd0 \
  -device virtio-blk,drive=hd1 \
  -blockdev driver=raw,node-name=hd0,file.driver=host_device,file.filename=${disk} \
  -blockdev driver=raw,node-name=hd1,file.driver=file,file.filename=${meta_tar}

tar xfv ${meta_tar} -C ${meta_dirout}
rm -rf ${meta_tar} ${meta_dir}
chmod 0755 ${meta_dirout}
echo "Extracted kyua reports to ${meta_dirout}"
