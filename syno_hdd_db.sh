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

# DONE
# Added check that M.2 volume support is enabled.
#
# Added support for M.2 SATA drives.
#
# Can now skip processing M.2 drives by running script with the -m2 flag.
#
# Changed method of getting drive and firmware version so script is faster and easier to maintain.
# - No longer using smartctl or hdparm.
#
# Changed SAS drive firmware version detection to support SAS drives that hdparm doesn't work with.
#
# Removed error message and aborting if *.db.new not found (clean DSM installs don't have a *.db.new).
#
# Force DSM to check disk compatibility so reboot not needed (DSM 6 may still need a reboot).
#
# Fixed DSM 6 issue when DSM 6 has the old db file format.
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


scriptver="v1.1.14"

# Check latest release with GitHub API
get_latest_release() {
    curl --silent "https://api.github.com/repos/$1/releases/latest" |
    grep '"tag_name":' |          # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'  # Pluck JSON value
}

tag=$(get_latest_release "007revad/Synology_HDD_db")

if ! printf "%s\n%s\n" "$tag" "$scriptver" |
        sort --check --version-sort &> /dev/null ; then
    echo -e "\e[0;36mThere is a newer version of this script available.\e[0m"
    echo -e "Current version: ${scriptver}\nLatest version:  $tag"
    echo "https://github.com/007revad/Synology_HDD_db/releases/latest"
    echo ""
    sleep 10
fi


# Check for flags with getopts
OPTERR=0
while getopts "sfnm" option; do
    # Need to ensure any other long flags do not contain s, n, or f
    if [[ ! ${#option} -gt "1" ]]; then
        case ${option,,,} in
            s)
                showedits=yes
                ;;
            n)
                nodbupdate=yes  # For future use
                ;;
            m)
                m2=no  # Don't add M.2 drives to db files
                ;;
            f)
                force=yes  # Disable "support_disk_compatibility"
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
    echo -e "\e[41mERROR\e[0m This script must be run as root or sudo!"
    exit 1
fi


#------------------------------------------------------------------------------
# Get list of installed SATA, SAS and M.2 NVMe/SATA drives

for d in /sys/block/*; do
    #echo $d  # debug
    case "$(basename -- "${d}")" in
        sd*|hd*)
            if [[ $d =~ [hs]d[a-z]$ ]]; then
                hdmodel=$(cat "$d/device/model")
                hdmodel=$(printf "%s" "$hdmodel" | xargs)  # trim leading and trailing white space
                #echo "Model:    '$hdmodel'"  # debug

                fwrev=$(cat "$d/device/rev")
                fwrev=$(printf "%s" "$fwrev" | xargs)  # trim leading and trailing white space
                #echo "Firmware: '$fwrev'"  # debug

                if [[ $hdmodel ]] && [[ $fwrev ]]; then
                    hdlist+=("${hdmodel},${fwrev}")
                fi
            fi
        ;;
        sata*|sas*)
            if [[ $d =~ (sas|sata)[0-9][0-9]?[0-9]?$ ]]; then
                hdmodel=$(cat "$d/device/model")
                hdmodel=$(printf "%s" "$hdmodel" | xargs)  # trim leading and trailing white space
                #echo "Model:    '$hdmodel'"  # debug

                fwrev=$(cat "$d/device/rev")
                fwrev=$(printf "%s" "$fwrev" | xargs)  # trim leading and trailing white space
                #echo "Firmware: '$fwrev'"  # debug

                if [[ $hdmodel ]] && [[ $fwrev ]]; then
                    hdlist+=("${hdmodel},${fwrev}")
                fi
            fi
        ;;
        nvme*)
            if [[ $d =~ nvme[0-9][0-9]?n[0-9][0-9]?$ ]]; then
                if [[ $m2 != "no" ]]; then
                    nvmemodel=$(cat "$d/device/model")
                    nvmemodel=$(printf "%s" "$nvmemodel" | xargs)  # trim leading and trailing white space
                    #echo "NVMe Model:    '$nvmemodel'"  # debug

                    nvmefw=$(cat "$d/device/firmware_rev")
                    nvmefw=$(printf "%s" "$nvmefw" | xargs)  # trim leading and trailing white space
                    #echo "NVMe Firmware: '$nvmefw'"  # debug

                    if [[ $nvmemodel ]] && [[ $nvmefw ]]; then
                        nvmelist+=("${nvmemodel},${nvmefw}")
                    fi
                fi
            fi
        ;;
        nvc*)  # M.2 SATA drives (in PCIe card only?)
            #if [[ $d =~ nvc[0-9][0-9]?p[0-9][0-9]?$ ]]; then
            if [[ $d =~ nvc[0-9][0-9]?$ ]]; then
                if [[ $m2 != "no" ]]; then
                    nvmemodel=$(cat "$d/device/model")
                    nvmemodel=$(printf "%s" "$nvmemodel" | xargs)  # trim leading and trailing white space
                    #echo "M.2 SATA Model:    '$nvmemodel'"  # debug

                    #nvmefw=$(cat "$d/device/firmware_rev")
                    nvmefw=$(cat "$d/device/rev")
                    nvmefw=$(printf "%s" "$nvmefw" | xargs)  # trim leading and trailing white space
                    #echo "M.2 SATA Firmware: '$nvmefw'"  # debug

                    if [[ $nvmemodel ]] && [[ $nvmefw ]]; then
                        nvmelist+=("${nvmemodel},${nvmefw}")
                    fi
                fi
            fi
        ;;
    esac
done


# Sort hdlist array into new hdds array to remove duplicates
if [[ ${#hdlist[@]} -gt "0" ]]; then
    while IFS= read -r -d '' x; do
        hdds+=("$x")
    done < <(printf "%s\0" "${hdlist[@]}" | sort -uz)
fi

# Check hdds array isn't empty
if [[ ${#hdds[@]} -eq "0" ]]; then
    echo -e "\e[41mERROR\e[0m No drives found!" && exit 2
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
    if [[ $m2 != "no" ]]; then
        echo -e "No M.2 drives found\n"
    fi
else    
    echo "M.2 drive models found: ${#nvmes[@]}"
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

if [[ ! -f "$db1" ]]; then echo -e "\e[41mERROR\e[0m $db1 not found!" && exit 3; fi
#if [[ ! -f "$db2" ]]; then echo -e "\e[41mERROR\e[0m $db2 not found!" && exit 4; fi
# new installs don't have a .db.new file


# Detect drive db type
if grep -F '{"disk_compatbility_info":' "$db1" >/dev/null; then
    # DSM 7 drive db files start with {"disk_compatbility_info":
    dbtype=7
elif grep -F '{"success":1,"list":[' "$db1" >/dev/null; then
    # DSM 6 drive db files start with {"success":1,"list":[
    dbtype=6
else
    echo -e "\e[41mERROR\e[0m Unknown database type $(basename -- "${db1}")!"
    exit 7
fi
#echo "dbtype: $dbtype"  # debug


# Backup database file if needed
if [[ ! -f "$db1.bak" ]]; then
    if cp "$db1" "$db1.bak"; then
        echo -e "Backed up database to $(basename -- "${db1}").bak\n"
    else
        echo -e "\e[41mERROR\e[0m Failed to backup $(basename -- "${db1}")!"
        exit 5
    fi
fi


# Shell Colors
Yellow='\e[0;33m'
Cyan='\e[0;36m'
Red='\e[0;31m'
Off=$'\e[0m'

function updatedb() {
    hdmodel=$(printf "%s" "$1" | cut -d"," -f 1)
    fwrev=$(printf "%s" "$1" | cut -d"," -f 2)

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
                echo -e "\n\e[41mERROR\e[0m Failed to update v7 $(basename -- "$2")${Off}"
                exit 6
            fi
        else
            # example:
            # {"model":"WD60EFRX-68MYMN1","firmware":"82.00A82","rec_intvl":[1]},
            # Don't need to add firmware version?
            #string="{\"model\":\"${hdmodel}\",\"firmware\":\"${fwrev}\",\"rec_intvl\":\[1\]},"
            string="{\"model\":\"${hdmodel}\",\"firmware\":\"\",\"rec_intvl\":\[1\]},"
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
                echo -e "\n\e[41mERROR\e[0m Failed to update $(basename -- "$2")${Off}"
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

# M.2 NVMe/SATA drives
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


# Check m2 volume support enabled
smp=support_m2_pool
setting="$(get_key_value /etc.defaults/synoinfo.conf ${smp})"
if [[ $setting == "no" ]]; then
    sed -i "s/${smp}=\"no\"/${smp}=\"yes\"/" "/etc.defaults/synoinfo.conf"
    setting="$(get_key_value /etc.defaults/synoinfo.conf ${smp})"
    if [[ $setting == "yes" ]]; then
        echo -e "\nEnabled M.2 volume support."
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
                echo -e "\e[41mERROR\e[0m Failed to backup $(basename -- "${file}")!"
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
                echo -e "\e[41mERROR\e[0m Failed to disable drive db auto updates!"
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
        elif [[ $db2Edits -gt "0" ]]; then
            echo -e "\nChanges to ${Cyan}$(basename -- "$db2")${Off}"
            jq . "$db2" | tail -n "$lines"
        fi
    else
        # Show first 8 lines per drive + 2
        lines=$(((db1Edits *8) +2))
        if [[ $db1Edits -gt "0" ]]; then
            echo -e "\nChanges to ${Cyan}$(basename -- "$db1")${Off}"
            jq . "$db1" | head -n "$lines"
        elif [[ $db2Edits -gt "0" ]]; then
            echo -e "\nChanges to ${Cyan}$(basename -- "$db2")${Off}"
            jq . "$db2" | head -n "$lines"
        fi
    fi
fi


# Make Synology check disk compatibility
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

