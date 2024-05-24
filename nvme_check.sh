#!/bin/bash
# shellcheck disable=SC2010,SC2059

# Files in /usr/syno/etc and /etc persist after DSM upgrade.
# Files in /usr/syno/etc.defaults and /etc.defaults are replaced during full DSM upgrade (micro update okay).
# Files in /run are generated when? They persist after micro update.
#
# Seems like /run/adapter_cards.conf generated at boot from /usr/syno/etc.defaults/adapter_cards.conf
#
# Except for synoinfo.conf which is different in /etc and /usr/syno/etc.defaults,
# I should backup files in /etc and /usr/syno/etc
# Backups in /etc.defaults and /usr/syno/etc.defaults are not persistent.

[[ $1 == --nologs ]] && nologs="yes"
[[ $1 == --nolog ]] && nologs="yes"

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
printf '/etc.defaults/synoinfo.conf: '"$(get_key_value /etc.defaults/synoinfo.conf support_m2_pool)"'\n'
printf '/etc/synoinfo.conf:          '"$(get_key_value /etc/synoinfo.conf support_m2_pool)"'\n'

echo -e '\n Checking supportnvme setting'
printf '/etc.defaults/synoinfo.conf: '"$(get_key_value /etc.defaults/synoinfo.conf supportnvme)"'\n'
printf '/etc/synoinfo.conf:          '"$(get_key_value /etc/synoinfo.conf supportnvme)"'\n'


echo -e '\n Checking synodisk --enum -t cache'
synodisk --enum -t cache

echo -e '\n Checking syno_slot_mapping'
printf -- '-%.0s' {1..40} && echo
syno_slot_mapping
printf -- '-%.0s' {1..40} && echo


echo -e '\n Checking udevadm nvme paths'
for nvme in /dev/nvme*n1; do
    printf "${nvme:5:-2}: "; udevadm info --query path --name "${nvme:5:-2}"
done

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



echo -e '\n Checking if nvme drives are detected with synonvme'
for nvme in /dev/nvme*n1; do
    if [[ -e $nvme ]]; then
        printf "${nvme:5:-2}: "; synonvme --is-nvme-ssd "$nvme"
        printf "${nvme:5:-2}: "; synonvme --vendor-get "$nvme"
        printf "${nvme:5:-2}: "; synonvme --model-get "$nvme"
    fi
done


echo -e '\n Checking nvme drives in /run/synostorage/disks'
ls /run/synostorage/disks | grep nv

echo -e '\n Checking nvme block devices in /sys/block'
ls /sys/block | grep nv


if [[ $nologs == "yes" ]]; then
    echo -e '\n Skipping checking logs'
else
    echo -e '\n Checking logs'
fi

printf -- '-%.0s' {1..40} && echo
echo "Current date/time:   $(date +"%Y-%m-%d %T")"
echo "Last boot date/time: $(uptime --since)"
booted="$(uptime --since | cut -d":" -f 1-2)"
printf -- '-%.0s' {1..40} && echo

exit


if [[ $nologs != "yes" ]]; then
    #grep nvme /var/log/synoscgi.log | tail -20 || echo "No synostgd-disk logs since last boot"
    #if ! journalctl -b | grep -v HISTORY | grep nvme ; then
    if ! journalctl -b -o short-iso | grep -v HISTORY |\
        grep -v data_collector | grep nvme | tail -30 ; then
        #grep -v data_collector | grep nvme ; then
        echo "No nvme logs since last boot"
    fi
fi

exit

