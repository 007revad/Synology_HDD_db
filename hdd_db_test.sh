#!/usr/bin/env bash
# shellcheck disable=SC1083,SC2054,SC2121,SC2207
#--------------------------------------------------------------------------------------------------
# Github: https://github.com/007revad/Synology_HDD_db
#--------------------------------------------------------------------------------------------------

scriptver="v3.1.64"
script=Synology_HDD_db
repo="007revad/Synology_HDD_db"

# Check BASH variable is bash
if [ ! "$(basename "$BASH")" = bash ]; then
    echo "This is a bash script. Do not run it with $(basename "$BASH")"
    printf \\a
    exit 1
fi

#echo -e "bash version: $(bash --version | head -1 | cut -d' ' -f4)\n"  # debug

ding(){
    printf \\a
}

usage(){
    cat <<EOF
$script $scriptver - by 007revad

Usage: $(basename "$0") [options]

Options:
  -s, --showedits       Show edits made to <model>_host db and db.new file(s)
  -n, --noupdate        Prevent DSM updating the compatible drive databases
  -m, --m2              Don't process M.2 drives
  -f, --force           Force DSM to not check drive compatibility
  -r, --ram             Disable memory compatibility checking (DSM 7.x only),
                        and sets max memory to the amount of installed memory
  -w, --wdda            Disable WD WDDA
  -i, --immutable       Enable immutable snapshots on models older than
                        20-series (DSM 7.2 and newer only).
  -e, --email           Disable colored text in output scheduler emails.
      --restore         Undo all changes made by the script
      --autoupdate=AGE  Auto update script (useful when script is scheduled)
                          AGE is how many days old a release must be before
                          auto-updating. AGE must be a number: 0 or greater
  -h, --help            Show this help message
  -v, --version         Show the script version

EOF
    exit 0
}


scriptversion(){
    cat <<EOF
$script $scriptver - by 007revad

See https://github.com/$repo
EOF
    exit 0
}


# Save options used
args=("$@")


# Check for flags with getopt
if options="$(getopt -o abcdefghijklmnopqrstuvwxyz0123456789 -l \
    restore,showedits,noupdate,nodbupdate,m2,force,ram,wdda,immutable,email,autoupdate:,help,version,debug \
    -- "$@")"; then
    eval set -- "$options"
    while true; do
        case "${1,,}" in
            --restore)          # Restore changes from backups
                restore=yes
                break
                ;;
            -s|--showedits)     # Show edits done to host db file
                showedits=yes
                ;;
            -n|--nodbupdate|--noupdate)  # Disable disk compatibility db updates
                nodbupdate=yes
                ;;
            -m|--m2)            # Don't add M.2 drives to db files
                m2=no
                ;;
            -f|--force)         # Disable "support_disk_compatibility"
                force=yes
                ;;
            -r|--ram)           # Disable "support_memory_compatibility"
                ram=yes
                ;;
            -i|--immutable)     # Enable "support_worm" (immutable snapshots)
                immutable=yes
                ;;
            -w|--wdda)          # Disable "support_memory_compatibility"
                wdda=no
                ;;
            -e|--email)         # Disable colour text in task scheduler emails
                color=no
                ;;
            --autoupdate)       # Auto update script
                autoupdate=yes
                if [[ $2 =~ ^[0-9]+$ ]]; then
                    delay="$2"
                    shift
                else
                    delay="0"
                fi
                ;;
            -h|--help)          # Show usage options
                usage
                ;;
            -v|--version)       # Show script version
                scriptversion
                ;;
            -d|--debug)         # Show and log debug info
                debug=yes
                ;;
            --)
                shift
                break
                ;;
            *)                  # Show usage options
                echo -e "Invalid option '$1'\n"
                usage "$1"
                ;;
        esac
        shift
    done
else
    echo
    usage
fi


if [[ $debug == "yes" ]]; then
    # set -x
    export PS4='`[[ $? == 0 ]] || echo "\e[1;31;40m($?)\e[m\n "`:.$LINENO:'
fi


# Shell Colors
if [[ $color != "no" ]]; then
    #Black='\e[0;30m'   # ${Black}
    Red='\e[0;31m'      # ${Red}
    #Green='\e[0;32m'   # ${Green}
    Yellow='\e[0;33m'   # ${Yellow}
    #Blue='\e[0;34m'    # ${Blue}
    #Purple='\e[0;35m'  # ${Purple}
    Cyan='\e[0;36m'     # ${Cyan}
    #White='\e[0;37m'   # ${White}
    Error='\e[41m'      # ${Error}
    Off='\e[0m'         # ${Off}
else
    echo ""  # For task scheduler email readability
fi


# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    ding
    echo -e "${Error}ERROR${Off} This script must be run as root or sudo!"
    exit 1
fi

# Get DSM major version
dsm=$(get_key_value /etc.defaults/VERSION majorversion)
if [[ $dsm -gt "6" ]]; then
    version="_v$dsm"
fi

# Get Synology model

# This doesn't work for drives migrated from different model
#model=$(find /var/lib/disk-compatibility -regextype egrep -regex ".*host(_v7)?\.db$" |\
#    cut -d"/" -f5 | cut -d"_" -f1 | uniq)

model=$(cat /proc/sys/kernel/syno_hw_version)
modelname="$model"


# Show script version
#echo -e "$script $scriptver\ngithub.com/${repo} TEST\n"
echo "$script $scriptver"

# Get DSM full version
productversion=$(get_key_value /etc.defaults/VERSION productversion)
buildphase=$(get_key_value /etc.defaults/VERSION buildphase)
buildnumber=$(get_key_value /etc.defaults/VERSION buildnumber)
smallfixnumber=$(get_key_value /etc.defaults/VERSION smallfixnumber)

# Show DSM full version and model
if [[ $buildphase == GM ]]; then buildphase=""; fi
if [[ $smallfixnumber -gt "0" ]]; then smallfix="-$smallfixnumber"; fi
echo "$model DSM $productversion-$buildnumber$smallfix $buildphase"


# Convert model to lower case
model=${model,,}

# Check for dodgy characters after model number
if [[ $model =~ 'pv10-j'$ ]]; then  # GitHub issue #10
    modelname=${modelname%??????}+  # replace last 6 chars with +
    model=${model%??????}+          # replace last 6 chars with +
    echo -e "\nUsing model: $model"
elif [[ $model =~ '-j'$ ]]; then  # GitHub issue #2
    modelname=${modelname%??}     # remove last 2 chars
    model=${model%??}             # remove last 2 chars
    echo -e "\nUsing model: $model"
fi

# Show options used
echo "Using options: ${args[*]}"

#echo ""  # To keep output readable


#------------------------------------------------------------------------------
# Check latest release with GitHub API


#------------------------------------------------------------------------------
# Restore changes from backups

dbpath=/var/lib/disk-compatibility/
synoinfo="/etc.defaults/synoinfo.conf"
adapter_cards="/usr/syno/etc.defaults/adapter_cards.conf"
modeldtb="/etc.defaults/model.dtb"

if [[ $restore == "yes" ]]; then
    dbbakfiles=($(find $dbpath -maxdepth 1 \( -name "*.db.new.bak" -o -name "*.db.bak" \)))
    echo

    if [[ ${#dbbakfiles[@]} -gt "0" ]] || [[ -f ${synoinfo}.bak ]] ||\
        [[ -f ${modeldtb}.bak ]] || [[ -f ${adapter_cards}.bak ]] ; then

        # Restore synoinfo.conf from backup
        if [[ -f ${synoinfo}.bak ]]; then
            if cp -p "${synoinfo}.bak" "${synoinfo}"; then
                echo -e "Restored $(basename -- "$synoinfo")\n"
            else
                restoreerr=1
                echo -e "${Error}ERROR${Off} Failed to restore synoinfo.conf!\n"
            fi
        fi

        # Restore adapter_cards.conf from backup
        if [[ -f ${adapter_cards}.bak ]]; then
            if cp -p "${adapter_cards}.bak" "${adapter_cards}"; then
                echo -e "Restored $(basename -- "$adapter_cards")\n"
            else
                restoreerr=1
                echo -e "${Error}ERROR${Off} Failed to restore adapter_cards.conf!\n"
            fi
        fi

        # Restore modeldtb from backup
        if [[ -f ${modeldtb}.bak ]]; then
            if cp -p "${modeldtb}.bak" "${modeldtb}"; then
                echo -e "Restored $(basename -- "$modeldtb")\n"
            else
                restoreerr=1
                echo -e "${Error}ERROR${Off} Failed to restore model.dtb!\n"
            fi
        fi

        # Restore .db files from backups
        for f in "${!dbbakfiles[@]}"; do
            replaceme="${dbbakfiles[f]%.bak}"  # Remove .bak
            if cp -p "${dbbakfiles[f]}" "$replaceme"; then
                echo "Restored $(basename -- "$replaceme")"
            else
                restoreerr=1
                echo -e "${Error}ERROR${Off} Failed to restore $(basename -- "$replaceme")!\n"
            fi
        done

        # Delete any .dbr and .db.newr files left by previous script versions
        for f in "${dbpath}"*dbr; do
            if [[ -f $f ]]; then
                rm "$f" >/dev/null
            fi
        done
        for f in "${dbpath}"*db.newr; do
            if [[ -f $f ]]; then
                rm "$f" >/dev/null
            fi
        done

        # Delete "drive_db_test_url=127.0.0.1" line (inc. line break) from /etc/synoinfo.conf
        sed -i "/drive_db_test_url=*/d" /etc/synoinfo.conf

        # Update .db files from Synology
        syno_disk_db_update --update

        # Enable SynoMemCheck.service for DVA models
        if [[ ${model:0:3} == "dva" ]]; then
            memcheck="/usr/lib/systemd/system/SynoMemCheck.service"
            if [[ $(synogetkeyvalue "$memcheck" ExecStart) == "/bin/true" ]]; then
                synosetkeyvalue "$memcheck" ExecStart /usr/syno/bin/syno_mem_check
            fi
        fi

        if [[ -z $restoreerr ]]; then
            echo -e "\nRestore successful."
        fi
    else
        echo "Nothing to restore."
    fi
    exit
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
        # See  Smartmontools database in /var/lib/smartmontools/drivedb.db
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

    # Skip USB drives
    usb=$(grep "$(basename -- "$1")" /proc/mounts | grep "[Uu][Ss][Bb]" | cut -d" " -f1-2)
    if [[ ! $usb ]]; then

        # Get drive model
        hdmodel=$(cat "$1/device/model")
        hdmodel=$(printf "%s" "$hdmodel" | xargs)  # trim leading and trailing white space

        # Fix dodgy model numbers
        fixdrivemodel "$hdmodel"

        # Get drive firmware version
        #fwrev=$(cat "$1/device/rev")
        #fwrev=$(printf "%s" "$fwrev" | xargs)  # trim leading and trailing white space

        device="/dev/$(basename -- "$1")"
        #fwrev=$(syno_hdd_util --ssd_detect | grep "$device " | awk '{print $2}')      # GitHub issue #86, 87
        # Account for SSD drives with spaces in their model name/number
        fwrev=$(syno_hdd_util --ssd_detect | grep "$device " | awk '{print $(NF-3)}')  # GitHub issue #86, 87

        if [[ $hdmodel ]] && [[ $fwrev ]]; then
            hdlist+=("${hdmodel},${fwrev}")
        fi
    fi
}

getm2info(){
    # $1 is /sys/block/nvme0n1 etc
    nvmemodel=$(cat "$1/device/model")
    nvmemodel=$(printf "%s" "$nvmemodel" | xargs)  # trim leading and trailing white space
    if [[ $2 == "nvme" ]]; then
        nvmefw=$(cat "$1/device/firmware_rev")
    elif [[ $2 == "nvc" ]]; then
        nvmefw=$(cat "$1/device/rev")
    fi
    nvmefw=$(printf "%s" "$nvmefw" | xargs)  # trim leading and trailing white space

    if [[ $nvmemodel ]] && [[ $nvmefw ]]; then
        nvmelist+=("${nvmemodel},${nvmefw}")
    fi
}

getcardmodel(){
    # Get M.2 card model (if M.2 drives found)
    # $1 is /dev/nvme0n1 etc
    if [[ ${#nvmelist[@]} -gt "0" ]]; then
        cardmodel=$(synodisk --m2-card-model-get "$1")
        if [[ $cardmodel =~ M2D[0-9][0-9] ]]; then
            # M2 adaptor card
            if [[ -f "${model}_${cardmodel,,}${version}.db" ]]; then
                m2carddblist+=("${model}_${cardmodel,,}${version}.db")  # M.2 card's db file
            fi
            if [[ -f "${model}_${cardmodel,,}.db" ]]; then
                m2carddblist+=("${model}_${cardmodel,,}.db")            # M.2 card's db file
            fi
            m2cardlist+=("$cardmodel")                                  # M.2 card
        elif [[ $cardmodel =~ E[0-9][0-9]+M.+ ]]; then
            # Ethernet + M2 adaptor card
            if [[ -f "${model}_${cardmodel,,}${version}.db" ]]; then
                m2carddblist+=("${model}_${cardmodel,,}${version}.db")  # M.2 card's db file
            fi
            if [[ -f "${model}_${cardmodel,,}.db" ]]; then
                m2carddblist+=("${model}_${cardmodel,,}.db")            # M.2 card's db file
            fi
            m2cardlist+=("$cardmodel")                                  # M.2 card
        fi
    fi
}

m2_pool_support(){
    if [[ -f /run/synostorage/disks/"$(basename -- "$1")"/m2_pool_support ]]; then  # GitHub issue #86, 87
        echo 1 > /run/synostorage/disks/"$(basename -- "$1")"/m2_pool_support
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
        nvme*)
            if [[ $d =~ nvme[0-9][0-9]?n[0-9][0-9]?$ ]]; then
                if [[ $m2 != "no" ]]; then
                    getm2info "$d" "nvme"
                    # Get M.2 card model if in M.2 card
                    getcardmodel "/dev/$(basename -- "${d}")"

                    # Enable creating M.2 storage pool and volume in Storage Manager
                    m2_pool_support "$d"

                    rebootmsg=yes  # Show reboot message at end
                fi
            fi
        ;;
        nvc*)  # M.2 SATA drives (in PCIe card only?)
            if [[ $d =~ nvc[0-9][0-9]?$ ]]; then
                if [[ $m2 != "no" ]]; then
                    getm2info "$d" "nvc"
                    # Get M.2 card model if in M.2 card
                    getcardmodel "/dev/$(basename -- "${d}")"

                    # Enable creating M.2 storage pool and volume in Storage Manager
                    m2_pool_support "$d"

                    rebootmsg=yes  # Show reboot message at end
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
    ding
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


# Sort nvmelist array into new nvmes array to remove duplicates
if [[ ${#nvmelist[@]} -gt "0" ]]; then
    while IFS= read -r -d '' x; do
        nvmes+=("$x")
    done < <(printf "%s\0" "${nvmelist[@]}" | sort -uz)        
fi

# Check nvmes array isn't empty
if [[ $m2 != "no" ]]; then
    if [[ ${#nvmes[@]} -eq "0" ]]; then
        echo -e "No M.2 drives found\n"
    else    
        m2exists="yes"
        echo "M.2 drive models found: ${#nvmes[@]}"
        num="0"
        while [[ $num -lt "${#nvmes[@]}" ]]; do
            echo "${nvmes[num]}"
            num=$((num +1))
        done
        echo
    fi
fi


# M.2 card db files
# Sort m2carddblist array into new m2carddbs array to remove duplicates
if [[ ${#m2carddblist[@]} -gt "0" ]]; then
    while IFS= read -r -d '' x; do
        m2carddbs+=("$x")
    done < <(printf "%s\0" "${m2carddblist[@]}" | sort -uz)        
fi

# M.2 cards
# Sort m2cardlist array into new m2cards array to remove duplicates
if [[ ${#m2cardlist[@]} -gt "0" ]]; then
    while IFS= read -r -d '' x; do
        m2cards+=("$x")
    done < <(printf "%s\0" "${m2cardlist[@]}" | sort -uz)        
fi

# Check m2cards array isn't empty
if [[ $m2 != "no" ]]; then
    if [[ ${#m2cards[@]} -eq "0" ]]; then
        echo -e "No M.2 PCIe cards found\n"
    else    
        echo "M.2 PCIe card models found: ${#m2cards[@]}"
        num="0"
        while [[ $num -lt "${#m2cards[@]}" ]]; do
            echo "${m2cards[num]}"
            num=$((num +1))
        done
        echo
    fi
fi


# Expansion units
# Create new /var/log/diskprediction log to ensure newly connected ebox is in latest log
# Otherwise the new /var/log/diskprediction log is only created a midnight.
syno_disk_data_collector record

# Get list of connected expansion units (aka eunit/ebox)
path="/var/log/diskprediction"
# shellcheck disable=SC2012
file=$(ls $path | tail -n1)
eunitlist=($(grep -Eowi "([FRD]XD?[0-9]{3,4})(rp|ii|sas){0,2}" "$path/$file" | uniq))

# Sort eunitlist array into new eunits array to remove duplicates
if [[ ${#eunitlist[@]} -gt "0" ]]; then
    while IFS= read -r -d '' x; do
        eunits+=("$x")
    done < <(printf "%s\0" "${eunitlist[@]}" | sort -uz)        
fi

# Check eunits array isn't empty
if [[ ${#eunits[@]} -eq "0" ]]; then
    echo -e "No Expansion Units found\n"
else    
    #eunitexists="yes"
    echo "Expansion Unit models found: ${#eunits[@]}"
    num="0"
    while [[ $num -lt "${#eunits[@]}" ]]; do
        echo "${eunits[num]}"
        num=$((num +1))
    done
    echo
fi


#------------------------------------------------------------------------------
# Check databases and add our drives if needed

# Host db files
db1list=($(find "$dbpath" -maxdepth 1 -name "*_host*.db"))
db2list=($(find "$dbpath" -maxdepth 1 -name "*_host*.db.new"))

# Expansion Unit db files
for i in "${!eunits[@]}"; do
    eunitdb1list=($(find "$dbpath" -maxdepth 1 -name "${eunits[i],,}*.db"))
    eunitdb2list=($(find "$dbpath" -maxdepth 1 -name "${eunits[i],,}*.db.new"))
done

# M.2 Card db files
for i in "${!m2cards[@]}"; do
    m2carddb1list=($(find "$dbpath" -maxdepth 1 -name "*_${m2cards[i],,}*.db"))
    m2carddb2list=($(find "$dbpath" -maxdepth 1 -name "*_${m2cards[i],,}*.db.new"))
done


if [[ ${#db1list[@]} -eq "0" ]]; then
    ding
    echo -e "${Error}ERROR 4${Off} Host db file not found!" && exit 4
fi
# Don't check .db.new as new installs don't have a .db.new file


getdbtype(){
    # Detect drive db type
    if grep -F '{"disk_compatbility_info":' "$1" >/dev/null; then
        # DSM 7 drive db files start with {"disk_compatbility_info":
        dbtype=7
    elif grep -F '{"success":1,"list":[' "$1" >/dev/null; then
        # DSM 6 drive db files start with {"success":1,"list":[
        dbtype=6
    else
        echo -e "${Error}ERROR${Off} Unknown database type $(basename -- "${1}")!" >&2
        dbtype=1
    fi
    #echo "db type: $dbtype" >&2  # debug
}


backupdb(){
    # Backup database file if needed
    if [[ ! -f "$1.bak" ]]; then
        if [[ $(basename "$1") == "synoinfo.conf" ]]; then
            echo "" >&2  # Formatting for stdout
        fi
        if cp -p "$1" "$1.bak"; then
            echo -e "Backed up $(basename -- "${1}")" >&2
        else
            echo -e "${Error}ERROR 5${Off} Failed to backup $(basename -- "${1}")!" >&2
            return 1
        fi
    fi
    # Fix permissions if needed
    octal=$(stat -c "%a %n" "$1" | cut -d" " -f1)
    if [[ ! $octal -eq 644 ]]; then
        chmod 644 "$1"
    fi
    return 0
}


# Backup host database file if needed
for i in "${!db1list[@]}"; do
    backupdb "${db1list[i]}" ||{
        ding
        exit 5
        }
done
for i in "${!db2list[@]}"; do
    backupdb "${db2list[i]}" ||{
        ding
        exit 5  # maybe don't exit for .db.new file
        }
done


#------------------------------------------------------------------------------
# Edit db files

editcount(){
    # Count drives added to host db files
    if [[ $1 =~ .*\.db$ ]]; then
        db1Edits=$((db1Edits +1))
    elif [[ $1 =~ .*\.db.new ]]; then
        db2Edits=$((db2Edits +1))
    fi
}


editdb7(){
    if [[ $1 == "append" ]]; then  # model not in db file
        #if sed -i "s/}}}/}},\"$hdmodel\":{$fwstrng$default/" "$2"; then  # append
        if sed -i "s/}}}/}},\"${hdmodel//\//\\/}\":{$fwstrng$default/" "$2"; then  # append
            echo -e "Added ${Yellow}$hdmodel${Off} to ${Cyan}$(basename -- "$2")${Off}"
            editcount "$2"
        else
            echo -e "\n${Error}ERROR 6a${Off} Failed to update $(basename -- "$2")${Off}"
            #exit 6
        fi

    elif [[ $1 == "insert" ]]; then  # model and default exists
        #if sed -i "s/\"$hdmodel\":{/\"$hdmodel\":{$fwstrng/" "$2"; then  # insert firmware
        if sed -i "s/\"${hdmodel//\//\\/}\":{/\"${hdmodel//\//\\/}\":{$fwstrng/" "$2"; then  # insert firmware
            echo -e "Updated ${Yellow}$hdmodel${Off} to ${Cyan}$(basename -- "$2")${Off}"
            #editcount "$2"
        else
            echo -e "\n${Error}ERROR 6b${Off} Failed to update $(basename -- "$2")${Off}"
            #exit 6
        fi

    elif [[ $1 == "empty" ]]; then  # db file only contains {}
        #if sed -i "s/{}/{\"$hdmodel\":{$fwstrng${default}}/" "$2"; then  # empty
        if sed -i "s/{}/{\"${hdmodel//\//\\/}\":{$fwstrng${default}}/" "$2"; then  # empty
            echo -e "Added ${Yellow}$hdmodel${Off} to ${Cyan}$(basename -- "$2")${Off}"
            editcount "$2"
        else
            echo -e "\n${Error}ERROR 6c${Off} Failed to update $(basename -- "$2")${Off}"
            #exit 6
        fi

    fi
}


updatedb(){
    hdmodel=$(printf "%s" "$1" | cut -d"," -f 1)
    fwrev=$(printf "%s" "$1" | cut -d"," -f 2)

    #echo arg1 "$1" >&2           # debug
    #echo arg2 "$2" >&2           # debug
    #echo hdmodel "$hdmodel" >&2  # debug
    #echo fwrev "$fwrev" >&2      # debug

    # Check if db file is new or old style
    getdbtype "$2"

    if [[ $dbtype -gt "6" ]]; then
        if grep "$hdmodel"'":{"'"$fwrev" "$2" >/dev/null; then
            echo -e "${Yellow}$hdmodel${Off} already exists in ${Cyan}$(basename -- "$2")${Off}" >&2
        else
            fwstrng=\"$fwrev\"
            fwstrng="$fwstrng":{\"compatibility_interval\":[{\"compatibility\":\"support\",\"not_yet_rolling_status\"
            fwstrng="$fwstrng":\"support\",\"fw_dsm_update_status_notify\":false,\"barebone_installable\":true}]},

            default=\"default\"
            default="$default":{\"compatibility_interval\":[{\"compatibility\":\"support\",\"not_yet_rolling_status\"
            default="$default":\"support\",\"fw_dsm_update_status_notify\":false,\"barebone_installable\":true}]}}}

            if grep '"disk_compatbility_info":{}' "$2" >/dev/null; then
               # Replace  "disk_compatbility_info":{}  with  "disk_compatbility_info":{"WD40PURX-64GVNY0":{"80.00A80":{ ... }}},"default":{ ... }}}}
                #echo "Edit empty db file:"  # debug
                editdb7 "empty" "$2"

            elif grep '"'"$hdmodel"'":' "$2" >/dev/null; then
               # Replace  "WD40PURX-64GVNY0":{  with  "WD40PURX-64GVNY0":{"80.00A80":{ ... }}},
                #echo "Insert firmware version:"  # debug
                editdb7 "insert" "$2"

            else
               # Add  "WD40PURX-64GVNY0":{"80.00A80":{ ... }}},"default":{ ... }}}
                #echo "Append drive and firmware:"  # debug
                editdb7 "append" "$2"
            fi
        fi
    elif [[ $dbtype -eq "6" ]]; then
        if grep "$hdmodel" "$2" >/dev/null; then
            echo -e "${Yellow}$hdmodel${Off} already exists in ${Cyan}$(basename -- "$2")${Off}" >&2
        else
            # example:
            # {"model":"WD60EFRX-68MYMN1","firmware":"82.00A82","rec_intvl":[1]},
            # Don't need to add firmware version?
            #string="{\"model\":\"${hdmodel}\",\"firmware\":\"${fwrev}\",\"rec_intvl\":\[1\]},"
            string="{\"model\":\"${hdmodel}\",\"firmware\":\"\",\"rec_intvl\":\[1\]},"
            # {"success":1,"list":[
            startstring="{\"success\":1,\"list\":\["
            # example:
            # {"success":1,"list":[{"model":"WD60EFRX-68MYMN1","firmware":"82.00A82","rec_intvl":[1]},
            #if sed -i "s/$startstring/$startstring$string/" "$2"; then
            if sed -i "s/${startstring//\//\\/}/${startstring//\//\\/}$string/" "$2"; then
                echo -e "Added ${Yellow}$hdmodel${Off} to ${Cyan}$(basename -- "$2")${Off}"
            else
                ding
                echo -e "\n${Error}ERROR 8${Off} Failed to update $(basename -- "$2")${Off}" >&2
                exit 8
            fi
        fi
    fi
}


# HDDs and SATA SSDs
num="0"
while [[ $num -lt "${#hdds[@]}" ]]; do
    for i in "${!db1list[@]}"; do
        updatedb "${hdds[$num]}" "${db1list[i]}"
    done
    for i in "${!db2list[@]}"; do
        updatedb "${hdds[$num]}" "${db2list[i]}"
    done

    #------------------------------------------------
    # Expansion Units
    for i in "${!eunitdb1list[@]}"; do
        backupdb "${eunitdb1list[i]}" &&\
            updatedb "${hdds[$num]}" "${eunitdb1list[i]}"
    done
    for i in "${!eunitdb2list[@]}"; do
        backupdb "${eunitdb2list[i]}" &&\
            updatedb "${hdds[$num]}" "${eunitdb2list[i]}"
    done
    #------------------------------------------------

    num=$((num +1))
done

# M.2 NVMe/SATA drives
num="0"
while [[ $num -lt "${#nvmes[@]}" ]]; do
    for i in "${!db1list[@]}"; do
        updatedb "${nvmes[$num]}" "${db1list[i]}"
    done
    for i in "${!db2list[@]}"; do
        updatedb "${nvmes[$num]}" "${db2list[i]}"
    done

    #------------------------------------------------
    # M.2 adaptor cards
    for i in "${!m2carddb1list[@]}"; do
        backupdb "${m2carddb1list[i]}" &&\
            updatedb "${nvmes[$num]}" "${m2carddb1list[i]}"
    done
    for i in "${!m2carddb2list[@]}"; do
        backupdb "${m2carddb2list[i]}" &&\
            updatedb "${nvmes[$num]}" "${m2carddb2list[i]}"
    done
    #------------------------------------------------

    num=$((num +1))
done


#------------------------------------------------------------------------------
# Enable unsupported Synology M2 PCIe cards

# DS1821+, DS1621+ and DS1520+ also need edited device tree blob file
# /etc.defaults/model.dtb
# RS822RP+, RS822+, RS1221RP+ and RS1221+ with DSM older than 7.2 need
# device tree blob file from DSM 7.2 to support M2D18

enable_card(){
    # $1 is the file
    # $2 is the section
    # $3 is the card model and mode
    if [[ -f $1 ]] && [[ -n $2 ]] && [[ -n $3 ]]; then
        # Check if section exists
        if ! grep '^\['"$2"'\]$' "$1" >/dev/null; then
            echo -e "Section [$2] not found in $(basename -- "$1")!" >&2
            return
        fi
        # Check if already enabled
        val=$(get_section_key_value "$1" "$2" "$modelname")
        if [[ $val != "yes" ]]; then
            if set_section_key_value "$1" "$2" "$modelname" yes; then
                echo -e "Enabled ${Yellow}$3${Off} for ${Cyan}$modelname${Off}" >&2
            else
                echo -e "${Error}ERROR 9${Off} Failed to enable $3 for ${modelname}!" >&2
            fi
        else
            echo -e "${Yellow}$3${Off} already enabled for ${Cyan}$modelname${Off}" >&2
        fi
    fi
}

check_modeldtb(){
    # $1 is E10M20-T1 or M2D20 or M2D18 or M2D17
    if [[ -f /etc.defaults/model.dtb ]]; then
        if ! grep --text "$1" /etc.defaults/model.dtb >/dev/null; then
            if [[ $modelname == "DS1821+" ]] || [[ $modelname == "DS1621+" ]] ||\
                [[ $modelname == "DS1520+" ]] || [[ $modelname == "RS822rp+" ]] ||\
                [[ $modelname == "RS822+" ]] || [[ $modelname == "RS1221rp+" ]] ||\
                [[ $modelname == "RS1221+" ]];
            then
                echo "" >&2
                if [[ -f ./dtb/${modelname}_model.dtb ]]; then

                    echo -e "\nEdited device tree blob exists in dtb folder with script\n"  # debug ####################################################

                    # Edited device tree blob exists in dtb folder with script
                    blob="./dtb/${modelname}_model.dtb"
                elif [[ -f ./${modelname}_model.dtb ]]; then

                    echo -e "\nEdited device tree blob exists with script\n"  # debug #################################################################

                    # Edited device tree blob exists with script
                    blob="./${modelname}_model.dtb"
                else
                    # Download edited device tree blob model.dtb from github
                    if cd /var/services/tmp; then
                        echo -e "Downloading ${modelname}_model.dtb" >&2
                        repo=https://github.com/007revad/Synology_HDD_db
                        url=${repo}/raw/main/dtb/${modelname}_model.dtb
                        curl -LJO -m 30 --connect-timeout 5 "$url"
                        echo "" >&2
                        cd "$scriptpath" || echo -e "${Error}ERROR${Off} Failed to cd to script location!"
                    else
                        echo -e "${Error}ERROR${Off} /var/services/tmp does not exist!" >&2
                    fi

                    # Check we actually downloaded the file
                    if [[ -f /var/services/tmp/${modelname}_model.dtb ]]; then
                        blob="/var/services/tmp/${modelname}_model.dtb"
                    else
                        echo -e "${Error}ERROR${Off} Failed to download ${modelname}_model.dtb!" >&2
                    fi
                fi
                if [[ -f $blob ]]; then
                    # Backup model.dtb
                    if ! backupdb "/etc.defaults/model.dtb"; then
                        echo -e "${Error}ERROR${Off} Failed to backup /etc.defaults/model.dtb!" >&2
                    else                
                        # Move and rename downloaded model.dtb
                        if mv "$blob" "/etc.defaults/model.dtb"; then
                            echo -e "Enabled ${Yellow}$1${Off} in ${Cyan}model.dtb${Off}" >&2
                        else
                            echo -e "${Error}ERROR${Off} Failed to add support for ${1}" >&2
                        fi

                        # Fix permissions if needed
                        octal=$(stat -c "%a %n" "/etc.defaults/model.dtb" | cut -d" " -f1)
                        if [[ ! $octal -eq 644 ]]; then
                            chmod 644 "/etc.defaults/model.dtb"
                        fi
                    fi
                else
                    #echo -e "${Error}ERROR${Off} Missing file ${modelname}_model.dtb" >&2
                    echo -e "${Error}ERROR${Off} Missing file $blob" >&2
                fi
            else
                echo -e "\n${Cyan}Contact 007revad to get an edited model.dtb file for your model.${Off}" >&2
            fi
        else
            echo -e "${Yellow}$1${Off} already enabled in ${Cyan}model.dtb${Off}" >&2
        fi
    fi
}


for c in "${m2cards[@]}"; do
    #echo ""
    m2cardconf="/usr/syno/etc.defaults/adapter_cards.conf"
    case "$c" in
        E10M20-T1)
            backupdb "$m2cardconf"
            echo ""
            enable_card "$m2cardconf" E10M20-T1_sup_nic "E10M20-T1 NIC"
            enable_card "$m2cardconf" E10M20-T1_sup_nvme "E10M20-T1 NVMe"
#            enable_card "$m2cardconf" E10M20-T1_sup_sata "E10M20-T1 SATA"
            check_modeldtb "$c"
        ;;
        M2D20)
            backupdb "$m2cardconf"
            echo ""
            enable_card "$m2cardconf" M2D20_sup_nvme "M2D20 NVMe"
            check_modeldtb "$c"
        ;;
        M2D18)
            backupdb "$m2cardconf"
            echo ""
            enable_card "$m2cardconf" M2D18_sup_nvme "M2D18 NVMe"
            enable_card "$m2cardconf" M2D18_sup_sata "M2D18 SATA"
            check_modeldtb "$c"
        ;;
        M2D17)
            backupdb "$m2cardconf"
            echo ""
            enable_card "$m2cardconf" M2D17_sup_sata "M2D17 SATA"
        ;;
        *)
            echo "Unknown M2 card type: $c"
        ;;
    esac
done



#------------------------------------------------------------------------------
# Edit /etc.defaults/synoinfo.conf

# Backup synoinfo.conf if needed
backupdb "$synoinfo" ||{
    ding
    exit 9
}

# Optionally disable "support_disk_compatibility"
sdc=support_disk_compatibility
setting="$(get_key_value $synoinfo $sdc)"
if [[ $force == "yes" ]]; then
    if [[ $setting == "yes" ]]; then
        # Disable support_disk_compatibility
        synosetkeyvalue "$synoinfo" "$sdc" "no"
        setting="$(get_key_value "$synoinfo" $sdc)"
        if [[ $setting == "no" ]]; then
            echo -e "\nDisabled support disk compatibility."
        fi
    elif [[ $setting == "no" ]]; then
        echo -e "\nSupport disk compatibility already disabled."
    fi
else
    if [[ $setting == "no" ]]; then
        # Enable support_disk_compatibility
        synosetkeyvalue "$synoinfo" "$sdc" "yes"
        setting="$(get_key_value "$synoinfo" $sdc)"
        if [[ $setting == "yes" ]]; then
            echo -e "\nRe-enabled support disk compatibility."
        fi
    elif [[ $setting == "yes" ]]; then
        echo -e "\nSupport disk compatibility already enabled."
    fi
fi


# Optionally disable "support_memory_compatibility" (not for DVA models)
if [[ ${model:0:3} != "dva" ]]; then
    smc=support_memory_compatibility
    setting="$(get_key_value $synoinfo $smc)"
    if [[ $ram == "yes" ]]; then
        if [[ $setting == "yes" ]]; then
            # Disable support_memory_compatibility
            synosetkeyvalue "$synoinfo" "$smc" "no"
            setting="$(get_key_value "$synoinfo" $smc)"
            if [[ $setting == "no" ]]; then
                echo -e "\nDisabled support memory compatibility."
            fi
        elif [[ $setting == "no" ]]; then
            echo -e "\nSupport memory compatibility already disabled."
        fi
    else
        if [[ $setting == "no" ]]; then
            # Enable support_memory_compatibility
            synosetkeyvalue "$synoinfo" "$smc" "yes"
            setting="$(get_key_value "$synoinfo" $smc)"
            if [[ $setting == "yes" ]]; then
                echo -e "\nRe-enabled support memory compatibility."
            fi
        elif [[ $setting == "yes" ]]; then
            echo -e "\nSupport memory compatibility already enabled."
        fi
    fi
fi

# Optionally disable SynoMemCheck.service for DVA models
if [[ ${model:0:3} == "dva" ]]; then
    memcheck="/usr/lib/systemd/system/SynoMemCheck.service"
    if [[ $(synogetkeyvalue "$memcheck" ExecStart) == "/usr/syno/bin/syno_mem_check" ]]; then
        synosetkeyvalue "$memcheck" ExecStart /bin/true
    fi
fi

# Optionally set mem_max_mb to the amount of installed memory
if [[ $dsm -gt "6" ]]; then  # DSM 6 as has no /proc/meminfo
    if [[ $ram == "yes" ]]; then
        # Get total amount of installed memory
        #IFS=$'\n' read -r -d '' -a array < <(dmidecode -t memory | grep "[Ss]ize")  # GitHub issue #86, 87
        IFS=$'\n' read -r -d '' -a array < <(dmidecode -t memory |\
            grep -E "[Ss]ize: [0-9]+ [MG]{1}[B]{1}$")  # GitHub issue #86, 87, 106
        if [[ ${#array[@]} -gt "0" ]]; then
            num="0"
            while [[ $num -lt "${#array[@]}" ]]; do
                check=$(printf %s "${array[num]}" | awk '{print $1}')
                if [[ ${check,,} == "size:" ]]; then
                    ramsize=$(printf %s "${array[num]}" | awk '{print $2}')           # GitHub issue #86, 87
                    bytes=$(printf %s "${array[num]}" | awk '{print $3}')             # GitHub issue #86, 87
                    if [[ $ramsize =~ ^[0-9]+$ ]]; then  # Check $ramsize is numeric  # GitHub issue #86, 87
                        if [[ $bytes == "GB" ]]; then    # DSM 7.2 dmidecode returned GB
                            ramsize=$((ramsize * 1024))  # Convert to MB              # GitHub issue #107
                        fi
                        if [[ $ramtotal ]]; then
                            ramtotal=$((ramtotal +ramsize))
                        else
                            ramtotal="$ramsize"
                        fi
                    fi
                fi
                num=$((num +1))
            done
        fi
        # Set mem_max_mb to the amount of installed memory
        setting="$(get_key_value $synoinfo mem_max_mb)"
        settingbak="$(get_key_value ${synoinfo}.bak mem_max_mb)"                      # GitHub issue #107
        if [[ $ramtotal =~ ^[0-9]+$ ]]; then   # Check $ramtotal is numeric
            if [[ $ramtotal -gt "$setting" ]]; then
                synosetkeyvalue "$synoinfo" mem_max_mb "$ramtotal"
                # Check we changed mem_max_mb
                setting="$(get_key_value $synoinfo mem_max_mb)"
                if [[ $ramtotal == "$setting" ]]; then
                    #echo -e "\nSet max memory to $ramtotal MB."
                    ramgb=$((ramtotal / 1024))
                    echo -e "\nSet max memory to $ramtotal GB."
                else
                    echo -e "\n${Error}ERROR${Off} Failed to change max memory!"
                fi

            elif [[ $setting -gt "$ramtotal" ]] && [[ $setting -gt "$settingbak" ]];  # GitHub issue #107 
            then
                # Fix setting is greater than both ramtotal and default in syninfo.conf.bak
                synosetkeyvalue "$synoinfo" mem_max_mb "$settingbak"
                # Check we restored mem_max_mb
                setting="$(get_key_value $synoinfo mem_max_mb)"
                if [[ $settingbak == "$setting" ]]; then
                    #echo -e "\nSet max memory to $ramtotal MB."
                    ramgb=$((ramtotal / 1024))
                    echo -e "\nRestored max memory to $ramtotal GB."
                else
                    echo -e "\n${Error}ERROR${Off} Failed to restore max memory!"
                fi

            elif [[ $ramtotal == "$setting" ]]; then
                #echo -e "\nMax memory already set to $ramtotal MB."
                ramgb=$((ramtotal / 1024))
                echo -e "\nMax memory already set to $ramgb GB."
            else [[ $ramtotal -lt "$setting" ]]
                #echo -e "\nMax memory is set to $setting MB."
                ramgb=$((setting / 1024))
                echo -e "\nMax memory is set to $ramgb GB."
            fi
        else
            echo -e "\n${Error}ERROR${Off} Total memory size is not numeric: '$ramtotal'"
        fi
    fi
fi


# Enable m2 volume support
if [[ $m2 != "no" ]]; then
    if [[ $m2exists == "yes" ]]; then
        # Check if m2 volume support is enabled
        smp=support_m2_pool
        setting="$(get_key_value $synoinfo ${smp})"
        enabled=""
        if [[ ! $setting ]]; then
            # Add support_m2_pool="yes"
            #echo 'support_m2_pool="yes"' >> "$synoinfo"
            synosetkeyvalue "$synoinfo" "$smp" "yes"
            enabled="yes"
        elif [[ $setting == "no" ]]; then
            # Change support_m2_pool="no" to "yes"
            synosetkeyvalue "$synoinfo" "$smp" "yes"
            enabled="yes"
        elif [[ $setting == "yes" ]]; then
            echo -e "\nM.2 volume support already enabled."
        fi

        # Check if we enabled m2 volume support
        setting="$(get_key_value $synoinfo ${smp})"
        if [[ $enabled == "yes" ]]; then
            if [[ $setting == "yes" ]]; then
                echo -e "\nEnabled M.2 volume support."
            else
                echo -e "\n${Error}ERROR${Off} Failed to enable m2 volume support!"
            fi
        fi
    fi
fi


# Edit synoinfo.conf to prevent drive db updates
dtu=drive_db_test_url
url="$(get_key_value $synoinfo ${dtu})"
disabled=""
if [[ $nodbupdate == "yes" ]]; then
    if [[ ! $url ]]; then
        # Add drive_db_test_url="127.0.0.1"
        #echo 'drive_db_test_url="127.0.0.1"' >> "$synoinfo"
        synosetkeyvalue "$synoinfo" "$dtu" "127.0.0.1"
        disabled="yes"
    elif [[ $url != "127.0.0.1" ]]; then
        # Edit drive_db_test_url=
        synosetkeyvalue "$synoinfo" "$dtu" "127.0.0.1"
        disabled="yes"
    fi

    # Check if we disabled drive db auto updates
    url="$(get_key_value $synoinfo drive_db_test_url)"
    if [[ $disabled == "yes" ]]; then
        if [[ $url == "127.0.0.1" ]]; then
            echo -e "\nDisabled drive db auto updates."
        else
            echo -e "\n${Error}ERROR${Off} Failed to disable drive db auto updates!"
        fi
    else
        echo -e "\nDrive db auto updates already disabled."
    fi
else
    # Re-enable drive db updates
    #if [[ $url == "127.0.0.1" ]]; then
    if [[ $url ]]; then
        # Delete "drive_db_test_url=127.0.0.1" line (inc. line break)
        sed -i "/drive_db_test_url=*/d" "$synoinfo"
        sed -i "/drive_db_test_url=*/d" /etc/synoinfo.conf

        # Check if we re-enabled drive db auto updates
        url="$(get_key_value $synoinfo drive_db_test_url)"
        if [[ $url != "127.0.0.1" ]]; then
            echo -e "\nRe-enabled drive db auto updates."
        else
            echo -e "\n${Error}ERROR${Off} Failed to enable drive db auto updates!"
        fi
    else
        echo -e "\nDrive db auto updates already enabled."
    fi
fi


# Optionally disable "support_wdda"
setting="$(get_key_value $synoinfo support_wdda)"
if [[ $wdda == "no" ]]; then
    if [[ $setting == "yes" ]]; then
        # Disable support_memory_compatibility
        synosetkeyvalue "$synoinfo" support_wdda "no"
        setting="$(get_key_value "$synoinfo" support_wdda)"
        if [[ $setting == "no" ]]; then
            echo -e "\nDisabled support WDDA."
        fi
    elif [[ $setting == "no" ]]; then
        echo -e "\nSupport WDDA already disabled."
    fi
fi


# Optionally enable "support_worm" (immutable snapshots)
setting="$(get_key_value $synoinfo support_worm)"
if [[ $immutable == "yes" ]]; then
    if [[ $setting != "yes" ]]; then
        # Disable support_memory_compatibility
        synosetkeyvalue "$synoinfo" support_worm "yes"
        setting="$(get_key_value "$synoinfo" support_worm)"
        if [[ $setting == "yes" ]]; then
            echo -e "\nEnabled Immutable Snapshots."
        fi
    elif [[ $setting == "no" ]]; then
        echo -e "\nImmutable Snapshots already enabled."
    fi
fi


#------------------------------------------------------------------------------
# Finished

# Show the changes
if [[ ${showedits,,} == "yes" ]]; then
    if [[ ${#db1list[@]} -gt "0" ]]; then
        getdbtype "${db1list[0]}"
        if [[ $dbtype -gt "6" ]]; then
            # Show 11 lines after hdmodel line
            lines=11
        elif [[ $dbtype -eq "6" ]]; then
            # Show 2 lines after hdmodel line
            lines=2
        fi

        # HDDs/SSDs
        for i in "${!hdds[@]}"; do
            hdmodel=$(printf "%s" "${hdds[i]}" | cut -d"," -f 1)
            echo
            jq . "${db1list[0]}" | grep -A "$lines" "$hdmodel"
        done

        # NVMe drives
        for i in "${!nvmes[@]}"; do
            hdmodel=$(printf "%s" "${nvmes[i]}" | cut -d"," -f 1)
            echo
            jq . "${db1list[0]}" | grep -A "$lines" "$hdmodel"
        done
    fi
fi


# Make Synology check disk compatibility
if [[ -f /usr/syno/sbin/synostgdisk ]]; then  # DSM 6.2.3 does not have synostgdisk
    /usr/syno/sbin/synostgdisk --check-all-disks-compatibility
    status=$?
    if [[ $status -eq "0" ]]; then
        echo -e "\nDSM successfully checked disk compatibility."
        rebootmsg=yes  # Show reboot message at end
    else
        # Ignore DSM 6.2.4 as it returns 255 for "synostgdisk --check-all-disks-compatibility"
        # and DSM 6.2.3 and lower have no synostgdisk command
        if [[ $dsm -gt "6" ]]; then
            echo -e "\nDSM ${Red}failed${Off} to check disk compatibility with exit code $status"
            rebootmsg=yes  # Show reboot message at end
        fi
    fi
fi

# Show reboot message if required
if [[ $dsm -eq "6" ]] || [[ $rebootmsg == "yes" ]]; then
    echo -e "\nYou may need to ${Cyan}reboot the Synology${Off} to see the changes."
fi


exit
