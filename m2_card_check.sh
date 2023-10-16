#!/bin/bash

# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    echo "This script must be run as sudo or root!"
    exit 1
fi

echo -e '\n Checking permissions and owner on model.dtb files'
ls -l /etc.defaults/model.dtb
ls -l /etc/model.dtb
ls -l /run/model.dtb


echo -e '\n Checking power_limit="100,100,100,100" is in model.dtb files'
files=( "/etc.defaults/model.dtb" "/etc/model.dtb" "/run/model.dtb" )
for i in "${!files[@]}"; do
    if ! grep "100,100,100,100" "${files[i]}" >/dev/null; then
        echo "Missing in ${files[i]}"
        error=$((error +1))
    fi
done
[[ $error -lt "1" ]] && echo "All OK"
error=""

echo -e '\n Checking E10M20-T1 is in model.dtb files'
files=( "/etc.defaults/model.dtb" "/etc/model.dtb" "/run/model.dtb" )
for i in "${!files[@]}"; do
    if ! grep "E10M20-T1" "${files[i]}" >/dev/null; then
        echo "Missing in ${files[i]}"
        error=$((error +1))
    fi
done
[[ $error -lt "1" ]] && echo "All OK"
error=""

echo -e '\n Checking M2D20 is in model.dtb files'
files=( "/etc.defaults/model.dtb" "/etc/model.dtb" "/run/model.dtb" )
for i in "${!files[@]}"; do
    if ! grep "M2D20" "${files[i]}" >/dev/null; then
        echo "Missing in ${files[i]}"
        error=$((error +1))
    fi
done
[[ $error -lt "1" ]] && echo "All OK"
error=""

echo -e '\n Checking M2D18 is in model.dtb files'
files=( "/etc.defaults/model.dtb" "/etc/model.dtb" "/run/model.dtb" )
for i in "${!files[@]}"; do
    if ! grep "M2D18" "${files[i]}" >/dev/null; then
        echo "Missing in ${files[i]}"
        error=$((error +1))
    fi
done
[[ $error -lt "1" ]] && echo "All OK"
error=""


echo -e '\n Checking /run/adapter_cards.conf'
if [[ ! $(get_key_value /run/adapter_cards.conf E10M20-T1_sup_nic) == "yes" ]]; then echo "E10M20-T1_sup_nic NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_key_value /run/adapter_cards.conf E10M20-T1_sup_nvme) == "yes" ]]; then echo "E10M20-T1_sup_nvme NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_key_value /run/adapter_cards.conf E10M20-T1_sup_sata) == "yes" ]]; then echo "E10M20-T1_sup_sata NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_key_value /run/adapter_cards.conf M2D20_sup_nvme) == "yes" ]]; then echo "M2D20_sup_nvme NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_key_value /run/adapter_cards.conf M2D18_sup_nvme) == "yes" ]]; then echo "M2D18_sup_nvme NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_key_value /run/adapter_cards.conf M2D18_sup_sata) == "yes" ]]; then echo "M2D18_sup_sata NOT set to yes"; error=$((error +1)); fi
#echo "error: $error"  # debug
if [[ $error -lt "1" ]]; then echo "All OK"; fi
error=""

echo -e '\n Checking /usr/syno/etc.defaults/adapter_cards.conf'
if [[ ! $(get_section_key_value /usr/syno/etc.defaults/adapter_cards.conf E10M20-T1_sup_nic DS1821+) == "yes" ]]; then echo "E10M20-T1_sup_nic NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_section_key_value /usr/syno/etc.defaults/adapter_cards.conf E10M20-T1_sup_nvme DS1821+) == "yes" ]]; then echo "E10M20-T1_sup_nvme NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_section_key_value /usr/syno/etc.defaults/adapter_cards.conf E10M20-T1_sup_sata DS1821+) == "yes" ]]; then echo "E10M20-T1_sup_sata NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_section_key_value /usr/syno/etc.defaults/adapter_cards.conf M2D20_sup_nvme DS1821+) == "yes" ]]; then echo "M2D20_sup_nvme NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_section_key_value /usr/syno/etc.defaults/adapter_cards.conf M2D18_sup_nvme DS1821+) == "yes" ]]; then echo "M2D18_sup_nvme NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_section_key_value /usr/syno/etc.defaults/adapter_cards.conf M2D18_sup_sata DS1821+) == "yes" ]]; then echo "M2D18_sup_sata NOT set to yes"; error=$((error +1)); fi
#echo "error: $error"  # debug
if [[ $error -lt "1" ]]; then echo "All OK"; fi
error=""

echo -e '\n Checking /usr/syno/etc/adapter_cards.conf'
if [[ ! $(get_section_key_value /usr/syno/etc/adapter_cards.conf E10M20-T1_sup_nic DS1821+) == "yes" ]]; then echo "E10M20-T1_sup_nic NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_section_key_value /usr/syno/etc/adapter_cards.conf E10M20-T1_sup_nvme DS1821+) == "yes" ]]; then echo "E10M20-T1_sup_nvme NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_section_key_value /usr/syno/etc/adapter_cards.conf E10M20-T1_sup_sata DS1821+) == "yes" ]]; then echo "E10M20-T1_sup_sata NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_section_key_value /usr/syno/etc/adapter_cards.conf M2D20_sup_nvme DS1821+) == "yes" ]]; then echo "M2D20_sup_nvme NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_section_key_value /usr/syno/etc/adapter_cards.conf M2D18_sup_nvme DS1821+) == "yes" ]]; then echo "M2D18_sup_nvme NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_section_key_value /usr/syno/etc/adapter_cards.conf M2D18_sup_sata DS1821+) == "yes" ]]; then echo "M2D18_sup_sata NOT set to yes"; error=$((error +1)); fi
#echo "error: $error"  # debug
if [[ $error -lt "1" ]]; then echo "All OK"; fi
error=""


# grep "DS1821+=no" /usr/syno/etc.defaults/adapter_cards.conf
# grep "DS1821+=no" /usr/syno/etc/adapter_cards.conf

# cat /run/adapter_cards.conf


echo -e '\n Checking synodisk --enum -t cache'
synodisk --enum -t cache

echo -e '\n Checking syno_slot_mapping'
syno_slot_mapping


echo -e '\n Checking udevadm nvme paths'
printf 'nvme0: '; udevadm info --query path --name nvme0
printf 'nvme1: '; udevadm info --query path --name nvme1
printf 'nvme2: '; udevadm info --query path --name nvme2
printf 'nvme3: '; udevadm info --query path --name nvme3

# # udevadm info --name nvme1
# P: /devices/pci0000:00/0000:00:01.3/0000:0d:00.0/nvme/nvme1
# N: nvme1
# E: DEVNAME=/dev/nvme1
# E: DEVPATH=/devices/pci0000:00/0000:00:01.3/0000:0d:00.0/nvme/nvme1
# E: MAJOR=250
# E: MINOR=1
# E: PHYSDEVBUS=pci
# E: PHYSDEVDRIVER=nvme
# E: PHYSDEVPATH=/devices/pci0000:00/0000:00:01.3/0000:0d:00.0
# E: SUBSYSTEM=nvme
# E: SYNO_INFO_PLATFORM_NAME=v1000
# E: SYNO_KERNEL_VERSION=4.4
# E: SYNO_SUPPORT_USB_PRINTER=yes
# E: SYNO_SUPPORT_XA=no
# E: USEC_INITIALIZED=384859


echo -e '\n Checking devicetree Power_limit'
cat /sys/firmware/devicetree/base/power_limit && echo


echo -e '\n Checking if nvme drives in PCIe card with synonvme'
printf 'nvme0: '; synonvme --m2-card-model-get /dev/nvme0
printf 'nvme1: '; synonvme --m2-card-model-get /dev/nvme1
printf 'nvme2: '; synonvme --m2-card-model-get /dev/nvme2
printf 'nvme3: '; synonvme --m2-card-model-get /dev/nvme3


echo -e '\n Checking if nvme drives in PCIe card with synodisk'
printf 'nvme0: '; synodisk --m2-card-model-get /dev/nvme0n1
printf 'nvme1: '; synodisk --m2-card-model-get /dev/nvme1n1
printf 'nvme2: '; synodisk --m2-card-model-get /dev/nvme2n1
printf 'nvme3: '; synodisk --m2-card-model-get /dev/nvme3n1


echo -e '\n Checking PCIe slot path(s)'
cat /etc.defaults/extensionPorts


echo -e '\n Checking nvme drives in /run/synostorage/disks'
ls /run/synostorage/disks | grep nv

echo -e '\n Checking nvme block devices in /sys/block'
ls /sys/block | grep nv

echo -e '\n Checking synostgd-disk log'
grep synostgd-disk /var/log/messages | tail -10

echo


