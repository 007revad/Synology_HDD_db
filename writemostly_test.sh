#!/usr/bin/env bash

set_writemostly(){ 
    # $1 is sata1 or sas1 or sda etc
    if [[ ${1::2} == "sd" ]]; then
        # sda etc

        # md0 DSM system partition
        echo writemostly > /sys/block/md0/md/dev-"${1}"1/state
        echo -n "md0 $1: " && cat /sys/block/md0/md/dev-"${1}"1/state  # debug

        # md1 DSM swap partition
        echo writemostly > /sys/block/md1/md/dev-"${1}"2/state
        echo -n "md1 $1: " && cat /sys/block/md1/md/dev-"${1}"2/state  # debug
    else
        # sata1 or sas1 etc

        # md0 DSM system partition
        echo writemostly > /sys/block/md0/md/dev-"${1}"p1/state
        echo -n "md0 $1: " && cat /sys/block/md0/md/dev-"${1}"p1/state  # debug

        # md1 DSM swap partition
        echo writemostly > /sys/block/md1/md/dev-"${1}"p2/state
        echo -n "md1 $1: " && cat /sys/block/md1/md/dev-"${1}"p2/state  # debug
    fi
}

# Get array of internal drives
readarray -t internal_drives < <(synodisk --enum -t internal | grep 'Disk path')

# Get list of HDDs and qty of SSDs
internal_ssd_qty="0"
for idrive in "${internal_drives[@]}"; do
    internal_drive="$(echo "$idrive" | awk '{printf $4}')"

    if synodisk --isssd "$internal_drive" >/dev/null; then
        # exit code 0 = is not SSD
        # exit code 1 = is SSD

        # Add internal HDDs to array
        internal_hdds+=("$internal_drive")
    else
        # Count number of 2.5 inch SSDs
        internal_ssd_qty=$((internal_ssd_qty +1))
    fi
done


echo "$internal_ssd_qty internal SSD"          # debug
echo -e "${#internal_hdds[@]} internal HDD\n"  # debug


# Set HDDs to writemostly if there's also internal SSDs
if [[ $internal_ssd_qty -gt "0" ]] && [[ ${#internal_hdds[@]} -gt "0" ]]; then
    # There are internal SSDs and HDDs
    for idrive in "${internal_hdds[@]}"; do
        #echo "$(basename -- "$idrive")"  # debug
        set_writemostly "$(basename -- "$idrive")"
        echo ""  # debug
    done
fi

exit

