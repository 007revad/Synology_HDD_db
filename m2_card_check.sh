#!/bin/bash

# Files in /usr/syno/etc and /etc persist after DSM upgrade.
# Files in /usr/syno/etc.defaults and /etc.defaults are replaced during full DSM upgrade (micro update okay).
# Files in /run are generated when? They persist after micro update.
#
# Seems like /run/adapter_cards.conf generated at boot from /usr/syno/etc.defaults/adapter_cards.conf
#
# Except for synoinfo.conf which is different in /etc and /usr/syno/etc.defaults,
# I should backup files in /etc and /usr/syno/etc
# Backups in /etc.defaults and /usr/syno/etc.defaults are not persistent.


# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    echo "This script must be run as sudo or root!"
    exit 1
fi

model=$(cat /proc/sys/kernel/syno_hw_version)
echo "$model"

os_name="DSM"
productversion=$(get_key_value /etc.defaults/VERSION productversion)
buildphase=" $(get_key_value /etc.defaults/VERSION buildphase)"
buildnumber=$(get_key_value /etc.defaults/VERSION buildnumber)
smallfixnumber=" $(get_key_value /etc.defaults/VERSION smallfixnumber)"
if [[ $buildphase == " GM" ]]; then
    buildphase=""
    if [[ $smallfixnumber ]]; then smallfixnumber=" Update$smallfixnumber"; fi
fi
echo "$os_name" "${productversion}-$buildnumber$buildphase$smallfixnumber"
date +"%Y-%m-%d %T"


echo -e '\n Checking support_m2_pool setting'
printf '/etc.defaults/synoinfo.conf: '$(get_key_value /etc.defaults/synoinfo.conf support_m2_pool)'\n'
printf '/etc/synoinfo.conf:          '$(get_key_value /etc/synoinfo.conf support_m2_pool)'\n'

echo -e '\n Checking supportnvme setting'
printf '/etc.defaults/synoinfo.conf: '$(get_key_value /etc.defaults/synoinfo.conf supportnvme)'\n'
printf '/etc/synoinfo.conf:          '$(get_key_value /etc/synoinfo.conf supportnvme)'\n'


echo -e '\n Checking md5 hash of libsynonvme.so.1'
case `md5sum -b /usr/lib/libsynonvme.so.1 | awk '{print $1}'` in
    2b41e149acdb7281f6145f9fae214285)
        # 7.2-64570		libsynonvme.so.1	2b41e149acdb7281f6145f9fae214285
        echo "libsynonvme.so.1 is 7.2-64570 version"
    ;;
    1726d502a568c0843d43a2d95bcc6566)
        # 7.2-64570-1	libsynonvme.so.1	1726d502a568c0843d43a2d95bcc6566
        # 7.2-64570-2	libsynonvme.so.1	1726d502a568c0843d43a2d95bcc6566
        # 7.2-64570-3	libsynonvme.so.1	1726d502a568c0843d43a2d95bcc6566
        echo "libsynonvme.so.1 is 7.2-64570-1, 2 or 3 version"
    ;;
    b4f3463cf353978209171b5fc5a4bc2c)
        # 7.2.1-69057-1	libsynonvme.so.1	b4f3463cf353978209171b5fc5a4bc2c
        echo "libsynonvme.so.1 is 7.2.1-69057-1 version"
    ;;
    *)
        echo "libsynonvme.so.1 is unknown version: $md5"
    ;;
esac

echo -e '\n Checking md5 hash of synonvme'
md5=$(md5sum -b /usr/syno/bin/synonvme | awk '{print $1}')
case "$md5" in
    ef36da23c30c17aeef6af943a958a124)
        # 7.2-64570		synonvme	ef36da23c30c17aeef6af943a958a124
        echo "synonvme is 7.2-64570 version"
    ;;
    97d51425e6ac48ce1ed5fafd8810d359)
        # 7.2-64570-1	synonvme	97d51425e6ac48ce1ed5fafd8810d359
        # 7.2-64570-2	synonvme	97d51425e6ac48ce1ed5fafd8810d359
        # 7.2-64570-3	synonvme	97d51425e6ac48ce1ed5fafd8810d359
        # 7.2.1-69057-1	synonvme	97d51425e6ac48ce1ed5fafd8810d359
        echo "synonvme is 7.2-64570-1 to 7.2.1-69057-1 version"
    ;;
    *)
        echo "synonvme is unknown version: $md5"
    ;;
esac


echo -e '\n Checking permissions and owner of libsynonvme.so.1'
echo " Which should be -rw-r--r-- 1 root root"
ls -l /usr/lib/libsynonvme.so.1

echo -e '\n Checking permissions and owner of synonvme'
echo " Which should be -rwxr-xr-x 1 root root"
ls -l /usr/syno/bin/synonvme


echo -e '\n Checking permissions and owner of model.dtb files'
echo " Which should be -rw-r--r-- 1 root root"
ls -l /etc.defaults/model.dtb
ls -l /etc/model.dtb
ls -l /run/model.dtb


echo -e '\n Checking if default power_limit="14.85,9.075" is in model.dtb files'
files=( "/etc.defaults/model.dtb" "/etc/model.dtb" "/run/model.dtb" )
for i in "${!files[@]}"; do
    if ! grep "14.85,9.075" "${files[i]}" >/dev/null; then
        echo "Missing in ${files[i]}"
        error=$((error +1))
    fi
done
[[ $error -lt "1" ]] && echo "All OK"
error=""

echo -e '\n Checking power_limit="14.85,14.85,14.85" is in model.dtb files'
files=( "/etc.defaults/model.dtb" "/etc/model.dtb" "/run/model.dtb" )
for i in "${!files[@]}"; do
    if ! grep "14.85,14.85,14.85" "${files[i]}" >/dev/null; then
        echo "Missing in ${files[i]}"
        error=$((error +1))
    fi
done
[[ $error -lt "1" ]] && echo "All OK"
error=""

echo -e '\n Checking power_limit="14.85,14.85,14.85,14.85" is in model.dtb files'
files=( "/etc.defaults/model.dtb" "/etc/model.dtb" "/run/model.dtb" )
for i in "${!files[@]}"; do
    if ! grep "14.85,14.85,14.85,14.85" "${files[i]}" >/dev/null; then
        echo "Missing in ${files[i]}"
        error=$((error +1))
    fi
done
[[ $error -lt "1" ]] && echo "All OK"
error=""

echo -e '\n Checking power_limit="100,100,100" is in model.dtb files'
files=( "/etc.defaults/model.dtb" "/etc/model.dtb" "/run/model.dtb" )
for i in "${!files[@]}"; do
    if ! grep "100,100,100" "${files[i]}" >/dev/null; then
        echo "Missing in ${files[i]}"
        error=$((error +1))
    fi
done
[[ $error -lt "1" ]] && echo "All OK"
error=""

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


echo -e '\n Checking permissions and owner of adapter_cards.conf files'
echo " Which should be -rw-r--r-- 1 root root"
ls -l /usr/syno/etc.defaults/adapter_cards.conf
ls -l /usr/syno/etc/adapter_cards.conf
ls -l /run/adapter_cards.conf

echo -e '\n Checking /usr/syno/etc.defaults/adapter_cards.conf'
if [[ ! $(get_section_key_value /usr/syno/etc.defaults/adapter_cards.conf E10M20-T1_sup_nic "$model") == "yes" ]]; then echo "E10M20-T1_sup_nic NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_section_key_value /usr/syno/etc.defaults/adapter_cards.conf E10M20-T1_sup_nvme "$model") == "yes" ]]; then echo "E10M20-T1_sup_nvme NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_section_key_value /usr/syno/etc.defaults/adapter_cards.conf E10M20-T1_sup_sata "$model") == "yes" ]]; then echo "E10M20-T1_sup_sata NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_section_key_value /usr/syno/etc.defaults/adapter_cards.conf M2D20_sup_nvme "$model") == "yes" ]]; then echo "M2D20_sup_nvme NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_section_key_value /usr/syno/etc.defaults/adapter_cards.conf M2D18_sup_nvme "$model") == "yes" ]]; then echo "M2D18_sup_nvme NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_section_key_value /usr/syno/etc.defaults/adapter_cards.conf M2D18_sup_sata "$model") == "yes" ]]; then echo "M2D18_sup_sata NOT set to yes"; error=$((error +1)); fi
#echo "error: $error"  # debug
if [[ $error -lt "1" ]]; then echo "All OK"; fi
error=""

echo -e '\n Checking /usr/syno/etc/adapter_cards.conf'  # Changes persist after DSM upgrade
if [[ ! $(get_section_key_value /usr/syno/etc/adapter_cards.conf E10M20-T1_sup_nic "$model") == "yes" ]]; then echo "E10M20-T1_sup_nic NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_section_key_value /usr/syno/etc/adapter_cards.conf E10M20-T1_sup_nvme "$model") == "yes" ]]; then echo "E10M20-T1_sup_nvme NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_section_key_value /usr/syno/etc/adapter_cards.conf E10M20-T1_sup_sata "$model") == "yes" ]]; then echo "E10M20-T1_sup_sata NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_section_key_value /usr/syno/etc/adapter_cards.conf M2D20_sup_nvme "$model") == "yes" ]]; then echo "M2D20_sup_nvme NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_section_key_value /usr/syno/etc/adapter_cards.conf M2D18_sup_nvme "$model") == "yes" ]]; then echo "M2D18_sup_nvme NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_section_key_value /usr/syno/etc/adapter_cards.conf M2D18_sup_sata "$model") == "yes" ]]; then echo "M2D18_sup_sata NOT set to yes"; error=$((error +1)); fi
#echo "error: $error"  # debug
if [[ $error -lt "1" ]]; then echo "All OK"; fi
error=""

echo -e '\n Checking /run/adapter_cards.conf'  # Generated by boot loader
if [[ ! $(get_key_value /run/adapter_cards.conf E10M20-T1_sup_nic) == "yes" ]]; then echo "E10M20-T1_sup_nic NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_key_value /run/adapter_cards.conf E10M20-T1_sup_nvme) == "yes" ]]; then echo "E10M20-T1_sup_nvme NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_key_value /run/adapter_cards.conf E10M20-T1_sup_sata) == "yes" ]]; then echo "E10M20-T1_sup_sata NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_key_value /run/adapter_cards.conf M2D20_sup_nvme) == "yes" ]]; then echo "M2D20_sup_nvme NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_key_value /run/adapter_cards.conf M2D18_sup_nvme) == "yes" ]]; then echo "M2D18_sup_nvme NOT set to yes"; error=$((error +1)); fi
if [[ ! $(get_key_value /run/adapter_cards.conf M2D18_sup_sata) == "yes" ]]; then echo "M2D18_sup_sata NOT set to yes"; error=$((error +1)); fi
#echo "error: $error"  # debug
if [[ $error -lt "1" ]]; then echo "All OK"; fi
error=""


# grep "${model}=no" /usr/syno/etc.defaults/adapter_cards.conf
# grep "${model}=no" /usr/syno/etc/adapter_cards.conf

# cat /run/adapter_cards.conf


echo -e '\n Checking synodisk --enum -t cache'
synodisk --enum -t cache

echo -e '\n Checking syno_slot_mapping'
printf -- '-%.0s' {1..40} && echo
syno_slot_mapping
printf -- '-%.0s' {1..40} && echo


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


echo -e '\n Checking if nvme drives in PCIe card are detected with synonvme'
printf 'nvme0: '; synonvme --m2-card-model-get /dev/nvme0
printf 'nvme1: '; synonvme --m2-card-model-get /dev/nvme1
printf 'nvme2: '; synonvme --m2-card-model-get /dev/nvme2
printf 'nvme3: '; synonvme --m2-card-model-get /dev/nvme3


echo -e '\n Checking if nvme drives in PCIe card are detected with synodisk'
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


echo -e '\n Checking synoscgi log'
printf -- '-%.0s' {1..40} && echo
echo "Current date/time:   $(date +"%Y-%m-%d %T")"
echo "Last boot date/time: $(uptime --since)"
booted="$(uptime --since | cut -d":" -f 1-2)"
printf -- '-%.0s' {1..40} && echo
#grep nvme /var/log/synoscgi.log | tail -20 || echo "No synostgd-disk logs since last boot"
if ! journalctl -b | grep -v HISTORY | grep nvme ; then
    echo "No nvme logs since last boot"
fi

exit
