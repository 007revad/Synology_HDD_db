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
#  or
# sudo /volume1/scripts/syno_hdd_db.sh -force -showedits
#--------------------------------------------------------------------------------------------------

# TODO
# Detect if expansion unit(s) connected and get model(s) and edit expansion unit db files.
#   Or add support for specifying user's expansion unit model(s) as arguments.
#   Or maybe use the shotgun approach and update all expansion unit db files.
#
# Add support for M.2 SATA and NVMe drives on a M2D17 PCI card.
#
# Maybe also edit the other disk compatibility DB in synoboot, used during boot time.
# It's also parsed and checked and probably in some cases it could be more critical to patch that one instead.
#
# Change SAS drive firmware version detection to use smartctl to support SAS drives that hdparm doesn't work with.

# DONE
# Make DSM recheck disk compatability so reboot not needed (DSM 7 only).
#
# Fixed DSM6 bug when DSM6 used the old db file format.
#
# Add support for SAS drives.
#
# Get HDD/SSD/SAS drive model number with smartctl instead of hdparm.
#
# Check if there is a newer script version available.
#
# Add support for NVMe drives.
#
# Prevent DSM auto updating the drive database.
#
# Optionally disable "support_disk_compatibility".


scriptver="1.1.10"

# Check latest release with GitHub API
get_latest_release() {
    curl --silent "https://api.github.com/repos/$1/releases/latest" |
    grep '"tag_name":' |          # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'  # Pluck JSON value
}

tag=$(get_latest_release "007revad/Synology_HDD_db")

if [[ ${tag:1} > "$scriptver" ]]; then
    echo "There is a newer version of this script available."
    echo -e "Current version: ${scriptver}\nLatest version:  ${tag:1}"
    echo "https://github.com/007revad/Synology_HDD_db/releases/latest"
    echo ""
    sleep 10
fi


# Check for flags with getopts
OPTERR=0
while getopts "sfn" option; do
    # Need to ensure any other long flags do not contain s, n, or f
    if [[ ! ${#option} -gt "1" ]]; then
        case ${option,,,} in
            s)
                showedits=yes
                #echo showedits  # debug
                ;;
            n)
                nodbupdate=yes  # For future use
                ;;
            f)
                force=yes
                ;;
            *)
                ;;
        esac
    fi
done


model=$(cat /proc/sys/kernel/syno_hw_version)
model=${model,,}  # convert to lower case

# Check for -j after model - GitHub issue #2
if [[ $model =~ '-j'$ ]]; then
    model=${model%??}  # remove last two chars
fi

# Get DSM major version
dsm=$(get_key_value /etc.defaults/VERSION majorversion)
if [[ $dsm -gt "6" ]]; then
    version="_v$dsm"
fi

# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    echo -e "\e[41m ERROR \e[0m This script must be run as root or sudo!"
    exit 1
fi


#------------------------------------------------------------------------------
# Get list of installed SATA, SAS and NVMe drives

getModel() {
    hdmodel=$(smartctl -i "$1" | grep -i "Device Model:" | awk '{print $3 $4 $5}')
    if [[ ! $hdmodel ]]; then
        hdmodel=$(smartctl -i "$1" | grep -i "Product:" | awk '{print $2 $3 $4}')
    fi
    #echo "Model:    $hdmodel"  # debug

    # Brands that return "BRAND <model>" and need "BRAND " removed.
    # Smartmontools database in /var/lib/smartmontools/drivedb.db
    hdmodel=${hdmodel#"WDC "}       # Remove "WDC " from start of model name
    hdmodel=${hdmodel#"HGST "}      # Remove "HGST " from start of model name
    hdmodel=${hdmodel#"TOSHIBA "}   # Remove "TOSHIBA " from start of model name

    # Old drive brands
    hdmodel=${hdmodel#"Hitachi "}   # Remove "Hitachi " from start of model name
    hdmodel=${hdmodel#"SAMSUNG "}   # Remove "SAMSUNG " from start of model name
    hdmodel=${hdmodel#"FUJISTU "}   # Remove "FUJISTU " from start of model name
    hdmodel=${hdmodel#"APPLE HDD "} # Remove "APPLE HDD " from start of model name

    shopt -s extglob
    hdmodel=${hdmodel/#*([[:space:]])}  # Remove leading spaces
    hdmodel=${hdmodel/%*([[:space:]])}  # Remove trailing spaces
    shopt -u extglob
    #echo "Model:    $hdmodel"  # debug
}

getFwVersion() {
    tmp=$(hdparm -i "$1" | grep Model)
    fwrev=$(printf %s "$tmp" | cut -d"," -f 2 | cut -d"=" -f 2)
    #echo "Firmware: $fwrev"  # debug
}

getNVMeModel() {
    nvmemodel=$(cat "$1"/model)
    shopt -s extglob
    nvmemodel=${nvmemodel/#*([[:space:]])}  # Remove leading spaces
    nvmemodel=${nvmemodel/%*([[:space:]])}  # Remove trailing spaces
    shopt -u extglob
    #echo "NVMe Model:    $nvmemodel"  # debug
}

getNVMeFwVersion() {
    nvmefw=$(cat "$1"/firmware_rev)
    nvmefw=$(echo "$nvmefw" | xargs)  # trim leading and trailing white space
    #echo "NVMe Firmware: $nvmefw"  # debug
}


for d in $(cat /proc/partitions | awk '{print $4}'); do
    if [ ! -e /dev/"$d" ]; then
        continue;
    fi
    #echo $d  # debug
    case "$d" in
        hd*|sd*)
            if [[ $d =~ [hs]d[a-z]{1,2}$ ]]; then
                #echo -e "\n$d"  # debug
                getModel "/dev/$d"
                getFwVersion "/dev/$d"
                if [[ $hdmodel ]] && [[ $fwrev ]]; then
                    hdparm+=("${hdmodel},${fwrev}")
                fi
            fi
        ;;
        sas*|sata*)
            if [[ $d =~ (sas|sata)[0-9][0-9]?[0-9]?$ ]]; then
                #echo -e "\n$d"  # debug
                getModel "/dev/$d"
                getFwVersion "/dev/$d"
                if [[ $hdmodel ]] && [[ $fwrev ]]; then
                    hdparm+=("${hdmodel},${fwrev}")
                fi
            fi
        ;;
        nvme*)
            if [[ $d =~ nvme[0-9][0-9]?n[0-9][0-9]?$ ]]; then
                #echo -e "\n$d"  # debug
                n=n$(printf "%s" "$d" | cut -d "n" -f 2)
                getNVMeModel "/sys/class/nvme/$n"
                getNVMeFwVersion "/sys/class/nvme/$n"
                if [[ $nvmemodel ]] && [[ $nvmefw ]]; then
                    nvmelist+=("${nvmemodel},${nvmefw}")
                fi
            fi
        ;;
    esac
done


# Sort hdparm array into new hdds array to remove duplicates
if [[ ${#hdparm[@]} -gt "0" ]]; then
    while IFS= read -r -d '' x; do
        hdds+=("$x")
    done < <(printf "%s\0" "${hdparm[@]}" | sort -uz)
fi

# Check hdds array isn't empty
if [[ ${#hdds[@]} -eq "0" ]]; then
    echo -e "\e[41m ERROR \e[0m No drives found!" && exit 2
else
    echo "HDD/SSD models found: ${#hdds[@]}"
    num="0"
    while [[ $num -lt "${#hdds[@]}" ]]; do
        echo "${hdds[num]}"
        num=$((num +1))
    done
    echo
fi


# Sort nvmelist array into new nvmes array to remove duplicates
if [[ ${#nvmelist[@]} -gt "0" ]]; then
    while IFS= read -r -d '' x; do
        nvmes+=("$x")
    done < <(printf "%s\0" "${nvmelist[@]}" | sort -uz)
fi

# Check nvmes array isn't empty
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


#------------------------------------------------------------------------------
# Check database and add our drives if needed

db1="/var/lib/disk-compatibility/${model}_host${version}.db"
db2="/var/lib/disk-compatibility/${model}_host${version}.db.new"

if [[ ! -f "$db1" ]]; then echo -e "\e[41m ERROR \e[0m $db1 not found!" && exit 3; fi
#if [[ ! -f "$db2" ]]; then echo -e "\e[41m ERROR \e[0m $db2 not found!" && exit 4; fi
# new installs don't have a .new file


# Detect drive db type
if grep -F '{"disk_compatbility_info":' "$db1" >/dev/null; then
    # DSM7 drive db files start with {"disk_compatbility_info":
    dbtype=7
elif grep -F '{"success":1,"list":[' "$db1" >/dev/null; then
    # DSM7 drive db files start with {"success":1,"list":[
    dbtype=6
else
    echo -e "\e[41m ERROR \e[0m Unknown database type $(basename -- "${db1}")!"
    exit 7
fi
#echo "dbtype: $dbtype"  # debug


# Backup database file if needed
if [[ ! -f "$db1.bak" ]]; then
    if cp "$db1" "$db1.bak"; then
        echo -e "Backed up database to $(basename -- "${db1}").bak\n"
    else
        echo -e "\e[41m ERROR \e[0m Failed to backup $(basename -- "${db1}")!"
        exit 5
    fi
fi


# Shell Colors
Yellow='\e[0;33m'
Cyan='\e[0;36m'
Red='\e[0;31m'
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
        if [[ $dbtype -gt "6" ]];then
            # Don't need to add firmware version?
            fwstrng=\"$fwrev\"
            fwstrng="$fwstrng":{\"compatibility_interval\":[{\"compatibility\":\"support\",\"not_yet_rolling_status\"
            fwstrng="$fwstrng":\"support\",\"fw_dsm_update_status_notify\":false,\"barebone_installable\":true}]},

            default=\"default\"
            default="$default":{\"compatibility_interval\":[{\"compatibility\":\"support\",\"not_yet_rolling_status\"
            default="$default":\"support\",\"fw_dsm_update_status_notify\":false,\"barebone_installable\":true}]}}}

            #if sed -i "s/}}}/}},\"$hdmodel\":{$fwstrng$default/" "$2"; then  # Don't need to add firmware version?
            if sed -i "s/}}}/}},\"$hdmodel\":{$default/" "$2"; then
                echo -e "Added ${Yellow}$hdmodel${Off} to ${Cyan}$(basename -- "$2")${Off}"
                if [[ $2 == "$db1" ]]; then
                    db1Edits=$((db1Edits +1))
                elif [[ $2 == "$db2" ]]; then
                    db2Edits=$((db2Edits +1))
                fi
            else
                echo -e "\n\e[41m ERROR \e[0m Failed to update v7 $(basename -- "$2")${Off}"
                exit 6
            fi
        else
            # example:
            # {"model":"WD60EFRX-68MYMN1","firmware":"82.00A82","rec_intvl":[1]},
            string="{\"model\":\"${hdmodel}\",\"firmware\":\"${fwrev}\",\"rec_intvl\":\[1\]},"
            # {"success":1,"list":[
            startstring="{\"success\":1,\"list\":\["

            #echo "$startstring"  # debug
            #echo "$string"       # debug
            #echo                 # debug

            # example:
            # {"success":1,"list":[{"model":"WD60EFRX-68MYMN1","firmware":"82.00A82","rec_intvl":[1]},
            if sed -ir "s/$startstring/$startstring$string/" "$2"; then
                echo -e "Added ${Yellow}$hdmodel${Off} to ${Cyan}$(basename -- "$2")${Off}"
                if [[ $2 == "$db1" ]]; then
                    db1Edits=$((db1Edits +1))
                elif [[ $2 == "$db2" ]]; then
                    db2Edits=$((db2Edits +1))
                fi
            else
                echo -e "\n\e[41m ERROR \e[0m Failed to update $(basename -- "$2")${Off}"
                exit 8
            fi
        fi
    fi
}

# HDDs and SATA SSDs
num="0"
while [[ $num -lt "${#hdds[@]}" ]]; do
    updatedb "${hdds[$num]}" "$db1"
    if [[ -f "$db2" ]]; then
        updatedb "${hdds[$num]}" "$db2"
    fi
    num=$((num +1))
done

# NVMe drives
num="0"
while [[ $num -lt "${#nvmes[@]}" ]]; do
    updatedb "${nvmes[$num]}" "$db1"
    if [[ -f "$db2" ]]; then
        updatedb "${nvmes[$num]}" "$db2"
    fi
    num=$((num +1))
done


# Optionally disable "support_disk_compatibility"
sdc=support_disk_compatibility
setting="$(get_key_value /etc.defaults/synoinfo.conf $sdc)"
if [[ $force == "yes" ]]; then
    if [[ $setting == "yes" ]]; then
        # Disable support_disk_compatibility
        sed -i "s/${sdc}=\"yes\"/${sdc}=\"no\"/" "/etc.defaults/synoinfo.conf"
        setting="$(get_key_value /etc.defaults/synoinfo.conf $sdc)"
        if [[ $setting == "no" ]]; then
            echo -e "\nDisabled support disk compatibility."
        fi
    fi
else
    if [[ $setting == "no" ]]; then
        # Enable support_disk_compatibility
        sed -i "s/${sdc}=\"no\"/${sdc}=\"yes\"/" "/etc.defaults/synoinfo.conf"
        setting="$(get_key_value /etc.defaults/synoinfo.conf $sdc)"
        if [[ $setting == "yes" ]]; then
            echo -e "\nRe-enabled support disk compatibility."
        fi
    fi
fi


# Edit synoinfo.conf to prevent DB updates
#if [[ $nodbupdate == "yes" ]]; then  # For future use
    file=/etc.defaults/synoinfo.conf
    if [[ -f $file ]]; then
        # Backup synoinfo.conf if needed
        if [[ ! -f "$file.bak" ]]; then
            if cp "$file" "$file.bak"; then
                echo "Backed up synoinfo.conf to $(basename -- "${file}").bak"
            else
                echo -e "\e[41m ERROR \e[0m Failed to backup $(basename -- "${file}")!"
                exit 6
            fi
        fi

        url=$(get_key_value "$file" drive_db_test_url)  # returns a linefeed if key doesn't exist
        if [[ ! $url ]]; then
            # Add drive_db_test_url=127.0.0.1
            echo "drive_db_test_url=127.0.0.1" >> "$file"
            disabled="yes"
        elif [[ $url != "127.0.0.1" ]]; then
            # Edit drive_db_test_url=
            sed -i "s/drive_db_test_url=$url/drive_db_test_url=127.0.0.1/" "$file"
            disabled="yes"
        fi

        url=$(get_key_value "$file" drive_db_test_url)
        if [[ $disabled == "yes" ]]; then
            if [[ $url == "127.0.0.1" ]]; then
                echo "Disabled drive db auto updates."
            else
                echo -e "\e[41m ERROR \e[0m Failed to disable drive db auto updates!"
            fi
        fi
    fi
#fi


# Show the changes
if [[ ${showedits,,} == "yes" ]]; then
    if [[ $dbtype -gt "6" ]];then
        # Show last 12 lines per drive + 4
        lines=$(((db1Edits *12) +4))
        if [[ $db1Edits -gt "0" ]]; then
            echo -e "\nChanges to ${Cyan}$(basename -- "$db1")${Off}"
            jq . "$db1" | tail -n "$lines"
        fi
        if [[ $db2Edits -gt "0" ]]; then
            echo -e "\nChanges to ${Cyan}$(basename -- "$db2")${Off}"
            jq . "$db2" | tail -n "$lines"
        fi
    else
        # Show first 8 lines per drive + 2
        lines=$(((db1Edits *8) +2))
        if [[ $db1Edits -gt "0" ]]; then
            echo -e "\nChanges to ${Cyan}$(basename -- "$db1")${Off}"
            jq . "$db1" | head -n "$lines"
        fi
        if [[ $db2Edits -gt "0" ]]; then
            echo -e "\nChanges to ${Cyan}$(basename -- "$db2")${Off}"
            jq . "$db2" | head -n "$lines"
        fi
    fi
fi


# Make Synology check disk compatability
/usr/syno/sbin/synostgdisk --check-all-disks-compatibility
status=$?
if [[ $status -eq "0" ]]; then
    echo -e "\nDSM successfully checked disk compatibility."
else
    # Ignore DSM 6 as it returns 255 for "synostgdisk --check-all-disks-compatibility"
    if [[ $dsm -gt "6" ]]; then
        echo -e "\nDSM ${Red}failed${Off} to check disk compatibility with exit code $status"
        echo -e "\nYou may need to ${Cyan}reboot the Synology${Off} to see the changes."
    fi
fi

if [[ $dsm -eq "6" ]]; then
    echo -e "\nYou may need to ${Cyan}reboot the Synology${Off} to see the changes."
fi


exit

