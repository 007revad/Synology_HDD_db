#!/usr/bin/env bash

# Shell Colors
#Red='\e[0;31m'
#Yellow='\e[0;33m'
#Cyan='\e[0;36m'
Error='\e[41m'
Off='\e[0m'


# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    echo -e "${Error}ERROR${Off} This script must be run as root or sudo!"
    exit 1
fi


#------------------------------------------------------------------------------
# Get list of installed SATA, SAS and M.2 NVMe/SATA drives,
# PCIe M.2 cards and connected Expansion Units.

fixdrivemodel(){
    # Remove " 00Y" from end of Samsung/Lenovo SSDs  # Github issue #13
    if [[ $1 =~ MZ.*" 00Y" ]]; then
        hdmodel=$(printf "%s" "$1" | sed 's/ 00Y.*//')
    fi

    # Brands that return "BRAND <model>" and need "BRAND " removed.
    if [[ $1 =~ ^[A-Za-z]{1,7}" ".* ]]; then
        #see  Smartmontools database in /var/lib/smartmontools/drivedb.db
        hdmodel=${hdmodel#"WDC "}       # Remove "WDC " from start of model name
        hdmodel=${hdmodel#"HGST "}      # Remove "HGST " from start of model name
        hdmodel=${hdmodel#"TOSHIBA "}   # Remove "TOSHIBA " from start of model name

        # Old drive brands
        hdmodel=${hdmodel#"Hitachi "}   # Remove "Hitachi " from start of model name
        hdmodel=${hdmodel#"SAMSUNG "}   # Remove "SAMSUNG " from start of model name
        hdmodel=${hdmodel#"FUJISTU "}   # Remove "FUJISTU " from start of model name
        hdmodel=${hdmodel#"APPLE HDD "} # Remove "APPLE HDD " from start of model name
    fi
}

getdriveinfo(){
    # $1 is /sys/block/sata1 etc

echo       # debug
echo "$1"  # debug

    # Skip USB drives
    usb=$(grep "$(basename -- "$1")" /proc/mounts | grep "[Uu][Ss][Bb]" | cut -d" " -f1-2)
    if [[ ! $usb ]]; then
        # Get drive model
        hdmodel=$(cat "$1/device/model")
        hdmodel=$(printf "%s" "$hdmodel" | xargs)  # trim leading and trailing white space

echo "Model: '$hdmodel'"  # debug

        # Fix dodgy model numbers
        fixdrivemodel "$hdmodel"

        # Get drive firmware version
        #fwrev=$(cat "$1/device/rev")
        #fwrev=$(printf "%s" "$fwrev" | xargs)  # trim leading and trailing white space

        device="/dev/$(basename -- "$1")"
        #fwrev=$(syno_hdd_util --ssd_detect | grep "$device" | awk '{print $2}')      # GitHub issue #86, 87
        # Account for SSD drives with spaces in their model name/number
        fwrev=$(syno_hdd_util --ssd_detect | grep "$device" | awk '{print $(NF-3)}')  # GitHub issue #86, 87

echo "FwRev: '$fwrev'"  # debug

        if [[ $hdmodel ]] && [[ $fwrev ]]; then
            hdlist+=("${hdmodel},${fwrev}")
        fi
    fi
}


for d in /sys/block/*; do
    # $d is /sys/block/sata1 etc
    case "$(basename -- "${d}")" in
        sd*|hd*)
            if [[ $d =~ [hs]d[a-z][a-z]?$ ]]; then
                # Get drive model and firmware version
                getdriveinfo "$d"
            fi
        ;;
        sata*|sas*)
            if [[ $d =~ (sas|sata)[0-9][0-9]?[0-9]?$ ]]; then
                # Get drive model and firmware version
                getdriveinfo "$d"
            fi
        ;;
    esac
done


echo -e "\nBefore sorting:"                   # debug
num="0"                                       # debug
while [[ $num -lt "${#hdlist[@]}" ]]; do        # debug
    echo "${hdlist[num]}"                       # debug
    num=$((num +1))                           # debug
done                                          # debug
#echo -e "\nAfter sorting:"                    # debug


# Sort hdlist array into new hdds array to remove duplicates
if [[ ${#hdlist[@]} -gt "0" ]]; then
    while IFS= read -r -d '' x; do
        hdds+=("$x")
    done < <(printf "%s\0" "${hdlist[@]}" | sort -uz)        
fi

# Check hdds array isn't empty
if [[ ${#hdds[@]} -eq "0" ]]; then
    echo -e "\n${Error}ERROR${Off} No drives found!" && exit 2
else
    echo -e "\nHDD/SSD models found: ${#hdds[@]}"
    num="0"
    while [[ $num -lt "${#hdds[@]}" ]]; do
        echo "${hdds[num]}"
        num=$((num +1))
    done
    echo
fi


exit

