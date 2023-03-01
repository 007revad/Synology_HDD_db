#!/usr/bin/env bash
# shellcheck disable=SC1083,SC2054,SC2121
#--------------------------------------------------------------------------------------------------
# Github: https://github.com/007revad/Synology_HDD_db
# Script verified at https://www.shellcheck.net/
# Tested on DSM 7.1.1 and DSM 6.2.4
#
# Easiest solution:
# Edit /etc.defaults/synoinfo.conf and change support_disk_compatibility="yes" to "no" and reboot.
# Then all drives can be used without error messages.
#
# But lets do this the proper way by adding our drive models to the appropriate .db file.
#
# To run in task manager as root (manually or scheduled):
# /volume1/scripts/syno_hdd_db.sh  # replace /volume1/scripts/ with path to script
#
# To run in a shell (replace /volume1/scripts/ with path to script):
# sudo /volume1/scripts/syno_hdd_db.sh
#  or
# sudo /volume1/scripts/syno_hdd_db.sh -showedits
#--------------------------------------------------------------------------------------------------

# TODO
# Detect if expansion unit(s) connected and get model(s) and edit expansion unit db files.
#   Or add support for specifying user's expansion unit model(s) as arguments.
#   Or maybe use the shotgun approach and update all expansion unit db files.
# Add support for SAS drives? Are are listed as /dev/sata# or /dev/sas# ?

# DONE
# Add support for NVMe drives.


# Check for -s or -showedits flag
if [[ ${1,,} == "-s" ]] || [[ ${1,,} == "-showedits" ]]; then showedits=yes; fi

model=$(cat /proc/sys/kernel/syno_hw_version)
model=${model,,}  # convert to lower case

# Check for -j after model - GitHub issue #2
if [[ $model =~ '-j'$ ]]; then
    model=${model%??}  # remove last to chars
fi

# Get DSM major version
dsm=$(get_key_value /etc.defaults/VERSION majorversion)
if [[ $dsm -gt "6" ]]; then
    version="_v$dsm"
fi

# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    echo -e "\e[41m ERROR:\e[0m This script must be run as root or sudo!"
    exit 1
fi


#------------------------------------------------------------------------------
# Get list of installed HDDs and SATA SSDs

# SATA drives, sata1, sata2 etc
for drive in /dev/sata*; do
    if [[ $drive =~ /dev/sata[1-9][0-9]?[0-9]?$ ]]; then
        tmp=$(hdparm -i "$drive" | grep Model)
        hdmodel=$(printf %s "$tmp" | cut -d"," -f 1 | cut -d"=" -f 2)
        fwrev=$(printf %s "$tmp" | cut -d"," -f 2 | cut -d"=" -f 2)
        if [[ $hdmodel ]] && [[ $fwrev ]]; then
            hdparm+=("${hdmodel},${fwrev}")
        fi
    fi
done

# SATA drives sda, sdb etc
for drive in /dev/sd*; do
    if [[ $drive =~ /dev/sd[a-z]{1,2}$ ]]; then
        tmp=$(hdparm -i "$drive" | grep Model)
        hdmodel=$(printf %s "$tmp" | cut -d"," -f 1 | cut -d"=" -f 2)
        fwrev=$(printf %s "$tmp" | cut -d"," -f 2 | cut -d"=" -f 2)
        if [[ $hdmodel ]] && [[ $fwrev ]]; then
            hdparm+=("${hdmodel},${fwrev}")
        fi
    fi
done

# Sort hdparm array into new hdds array to remove duplicates
if [[ ${#hdparm[@]} -gt "0" ]]; then
    while IFS= read -r -d '' x; do
        hdds+=("$x")
    done < <(printf "%s\0" "${hdparm[@]}" | sort -uz)
fi

# Check hdds array isn't empty
if [[ ${#hdds[@]} -eq "0" ]]; then
    echo -e "\e[41m ERROR:\e[0m No drives found!" && exit 2
else
    echo "HDD/SSD models found: ${#hdds[@]}"
    num="0"
    while [[ $num -lt "${#hdds[@]}" ]]; do
        echo "${hdds[num]}"
        num=$((num +1))
    done
    echo
fi


#------------------------------------------------------------------------------
# Get list of installed NVMe drives

express=$(cat /proc/devices | grep nvme)
if [[ $express ]]; then
    for path in /sys/class/nvme/*; do
        nvmemodel=$(cat "$path"/model)
        nvmemodel=$(echo "$nvmemodel" | xargs)  # trim leading and trailing white space
        #if [[ $nvmemodel ]]; then echo "NVMe model:    ${nvmemodel}"; fi  # debug

        nvmefw=$(cat "$path"/firmware_rev)
        nvmefw=$(echo "$nvmefw" | xargs)  # trim leading and trailing white space
        #if [[ $nvmefw ]]; then echo "NVMe firmware: ${nvmefw}"; fi  # debug

        if [[ $nvmemodel ]] && [[ $nvmefw ]]; then
            nvmelist+=("${nvmemodel},${nvmefw}")
        fi
    done

    # Sort nvmelist array into new nvmes array to remove duplicates
    if [[ ${#nvmelist[@]} -gt "0" ]]; then
        while IFS= read -r -d '' x; do
            nvmes+=("$x")
        done < <(printf "%s\0" "${nvmelist[@]}" | sort -uz)
    fi

    # Check hdds array isn't empty
    if [[ ${#nvmes[@]} -eq "0" ]]; then
        echo -e "No NVMe drives found\n"
    else    
        echo "NVMe drive models found: ${#nvmes[@]}"
        num="0"
        while [[ $num -lt "${#nvmes[@]}" ]]; do
            echo "${nvmes[num]}"
            num=$((num +1))
        done
        echo
    fi
fi


#------------------------------------------------------------------------------
# Check database and add our drives if needed

db1="/var/lib/disk-compatibility/${model}_host${version}.db"
db2="/var/lib/disk-compatibility/${model}_host${version}.db.new"

if [[ ! -f "$db1" ]]; then echo -e "\e[41m ERROR:\e[0m $db1 not found!" && exit 3; fi
if [[ ! -f "$db2" ]]; then echo -e "\e[41m ERROR:\e[0m $db2 not found!" && exit 4; fi


# Backup database file if needed
if [[ ! -f "$db1.bak" ]]; then
    if cp "$db1" "$db1.bak"; then
        echo -e "Backed up database to $(basename -- "${db1}").bak\n"
    else
        echo -e "\e[41m ERROR:\e[0m Failed to backup $(basename -- "${db1}")!"
        exit 5
    fi
fi


# Shell Colors
Yellow='\e[0;33m'
Cyan='\e[0;36m'
Off=$'\e[0m'

function updatedb() {
    hdmodel=$(printf %s "$1" | cut -d"," -f 1)
    fwrev=$(printf %s "$1" | cut -d"," -f 2)

    #echo arg1 "$1"           # debug
    #echo arg2 "$2"           # debug
    #echo hdmodel "$hdmodel"  # debug
    #echo fwrev "$fwrev"      # debug

    if grep "$hdmodel" "$2" >/dev/null; then
        echo -e "${Yellow}$hdmodel${Off} already exists in ${Cyan}$(basename -- "$2")${Off}"
    else
        # Don't need to add firmware version?
        fwstrng=\"$fwrev\"
        fwstrng="$fwstrng":{\"compatibility_interval\":[{\"compatibility\":\"support\",\"not_yet_rolling_status\"
        fwstrng="$fwstrng":\"support\",\"fw_dsm_update_status_notify\":false,\"barebone_installable\":true}]},

        default=\"default\"
        default="$default":{\"compatibility_interval\":[{\"compatibility\":\"support\",\"not_yet_rolling_status\"
        default="$default":\"support\",\"fw_dsm_update_status_notify\":false,\"barebone_installable\":true}]}}}

        #if sed -i "s/}}}/}},\"$hdmodel\":{$fwstrng$default/g" "$2"; then  # Don't need to add firmware version?
        if sed -i "s/}}}/}},\"$hdmodel\":{$default/g" "$2"; then
            #echo "Added $hdmodel to $(basename -- "$2")"
            echo -e "Added ${Yellow}$hdmodel${Off} to ${Cyan}$(basename -- "$2")${Off}"
            if [[ $2 == "$db1" ]]; then
                db1Edits=$((db1Edits +1))
            elif [[ $2 == "$db2" ]]; then
                db2Edits=$((db2Edits +1))
            fi
        else
            echo -e "\n\e[41m ERROR: Failed to update $(basename -- "$2")${Off}"
            exit 6
        fi
    fi
}

# HDDs and SATA SSDs
num="0"
while [[ $num -lt "${#hdds[@]}" ]]; do
    updatedb "${hdds[$num]}" "$db1"
    updatedb "${hdds[$num]}" "$db2"
    num=$((num +1))
done

# NVMe drives
num="0"
while [[ $num -lt "${#nvmes[@]}" ]]; do
    updatedb "${nvmes[$num]}" "$db1"
    updatedb "${nvmes[$num]}" "$db2"
    num=$((num +1))
done

# Brute force method just in case
sdc=support_disk_compatibility
setting="$(get_key_value /etc.defaults/synoinfo.conf $sdc)"
if [[ $setting == "yes" ]]; then
    sed -i "s/${sdc}=\"yes\"/${sdc}=\"no\"/g" "/etc.defaults/synoinfo.conf"
fi

# Show the changes
if [[ ${showedits,,} == "yes" ]]; then
    lines=$(((db2Edits *12) +4))
    if [[ $db1Edits -gt "0" ]]; then
        echo -e "\nChanges to ${Cyan}$(basename -- "$db1")${Off}"
        jq . "$db1" | tail -n "$lines"  # show last 20 lines per edit
    fi
    if [[ $db2Edits -gt "0" ]]; then
        echo -e "\nChanges to ${Cyan}$(basename -- "$db2")${Off}"
        jq . "$db2" | tail -n "$lines"  # show last 20 lines per edit
    fi
fi

echo -e "\nYou may need to ${Cyan}reboot the Synology${Off} to see the changes."

exit

