#!/usr/bin/env bash
# shellcheck disable=SC1083,SC2054,SC2121
#--------------------------------------------------------------------------------------------------
# Github: https://github.com/007revad/Synology_HDD_db
# Script verified at https://www.shellcheck.net/
# Tested on DSM 7.2 beta, 7.1.1 and DSM 6.2.4
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
# Bypass M.2 volume lock for unsupported M.2 drives.
#
# Maybe also edit the other disk compatibility db in synoboot, used during boot time.
# It's also parsed and checked and probably in some cases it could be more critical to patch that one instead.

# DONE
# Fixed "download new version" failing if script was run via symlink or ./<scriptname>
#
# Changed to show if no M.2 cards were found, if M.2 drives were found.
#
# Changed latest version check to download to /tmp and extract files to the script's location,
# replacing the existing .sh and readme.txt files.
#
# Added a timeouts when checking for newer script version in case github is down or slow.
#
# Added option to disable incompatible memory notifications.
#
# Now finds your expansion units' model numbers and adds your drives to their db files.
#
# Now adds your M.2 drives to your M.2 PCI cards db files (M2Dxx and E10M20-T1 and future models).
#
# Improved flags/options checking and added usage help.
#
# Can now download the latest script version for you (if you have user home service enabled in DSM).
#
# Now adds 'support_m2_pool="yes"' line for models that don't have support_m2_pool in synoinfo.conf
#   to (hopefully) prevent losing your SSH created M2 volume when running this script on models 
#   that DSM 7.2 Beta does not list as supported for creating M2 volumes.
#
# Changed Synology model detection to be more reliable (for models that came in different variations).
#
# Changed checking drive_db_test_url setting to be more durable.
#
# Added removal of " 00Y" from end of Samsung/Lenovo SSDs to fix issue #13.
#
# Fixed bug where removable drives were being detected and added to drive database.
#
# Fixed bug where "M.2 volume support already enabled" message appeared when NAS had no M.2 drives.
#
# Added check that M.2 volume support is enabled (on supported models).
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


scriptver="v1.2.30"
script=Synology_HDD_db
repo="007revad/Synology_HDD_db"

#echo -e "bash version: $(bash --version | head -1 | cut -d' ' -f4)\n"  # debug

# Shell Colors
#Black='\e[0;30m'
Red='\e[0;31m'
#Green='\e[0;32m'
Yellow='\e[0;33m'
#Blue='\e[0;34m'
#Purple='\e[0;35m'
Cyan='\e[0;36m'
#White='\e[0;37m'
Error='\e[41m'
Off='\e[0m'


usage(){
    cat <<EOF
$script $scriptver - by 007revad

Usage: $(basename "$0") [options]

Options:
  -s, --showedits  Show edits made to <model>_host db and db.new file(s)
  -n, --noupdate   Prevent DSM updating the compatible drive databases
  -m, --m2         Don't process M.2 drives
  -f, --force      Force DSM to not check drive compatibility
  -r, --ram        Disable memory compatibility checking
  -h, --help       Show this help message
  -v, --version    Show the script version
  
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


# Check for flags with getopt
if options="$(getopt -o abcdefghijklmnopqrstuvwxyz0123456789 -a \
    -l showedits,noupdate,nodbupdate,m2,force,ram,help,version,debug -- "$@")"; then
    eval set -- "$options"
    while true; do
        case "${1,,}" in
            -s|--showedits)     # Show edits done to host db file
                showedits=yes
                ;;
            -n|--nodbupdate|--noupdate)    # Disable disk compatibility db updates
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
                echo "Invalid option '$1'"
                usage "$1"
                ;;
        esac
        shift
    done
fi


# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
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


# Show script version
#echo -e "$script $scriptver\ngithub.com/$repo\n"
echo "$script $scriptver"

# Show DSM full version
productversion=$(get_key_value /etc.defaults/VERSION productversion)
buildphase=$(get_key_value /etc.defaults/VERSION buildphase)
buildnumber=$(get_key_value /etc.defaults/VERSION buildnumber)
if [[ $buildphase == GM ]]; then buildphase=""; fi
echo "$model DSM $productversion-$buildnumber $buildphase"


# Convert model to lower case
model=${model,,}

# Check for dodgy characters after model number
if [[ $model =~ 'pv10-j'$ ]]; then  # GitHub issue #10
    model=${model%??????}+  # replace last 6 chars with +
    echo "Using model: $model"
elif [[ $model =~ '-j'$ ]]; then  # GitHub issue #2
    model=${model%??}  # remove last 2 chars
    echo "Using model: $model"
fi

echo ""  # To keep output readable


#------------------------------------------------------------------------------
# Check latest release with GitHub API

get_latest_release() {
    # Curl timeout options:
    # https://unix.stackexchange.com/questions/94604/does-curl-have-a-timeout
    curl --silent -m 10 --connect-timeout 5 \
        "https://api.github.com/repos/$1/releases/latest" |
    grep '"tag_name":' |          # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'  # Pluck JSON value
}

tag=$(get_latest_release "$repo")
shorttag="${tag:1}"
#scriptpath=$(dirname -- "$0")

# Get script location
source=${BASH_SOURCE[0]}
while [ -L "$source" ]; do # Resolve $source until the file is no longer a symlink
    scriptpath=$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )
    source=$(readlink "$source")
    # If $source was a relative symlink, we need to resolve it 
    # relative to the path where the symlink file was located
    [[ $source != /* ]] && source=$scriptpath/$source
done
scriptpath=$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )
#echo "Script location: $scriptpath"  # debug


if ! printf "%s\n%s\n" "$tag" "$scriptver" |
        sort --check --version-sort &> /dev/null ; then
    echo -e "${Cyan}There is a newer version of this script available.${Off}"
    echo -e "Current version: ${scriptver}\nLatest version:  $tag"
    if [[ -f $scriptpath/$script-$shorttag.tar.gz ]]; then
        # They have the latest version tar.gz downloaded but are using older version
        echo "https://github.com/$repo/releases/latest"
        sleep 10
    elif [[ -d $scriptpath/$script-$shorttag ]]; then
        # They have the latest version extracted but are using older version
        echo "https://github.com/$repo/releases/latest"
        sleep 10
    else
        echo -e "${Cyan}Do you want to download $tag now?${Off} [y/n]"
        read -r -t 30 reply
        if [[ ${reply,,} == "y" ]]; then
            if cd /tmp; then
                url="https://github.com/$repo/archive/refs/tags/$tag.tar.gz"
                if ! curl -LJO -m 30 --connect-timeout 5 "$url";
                then
                    echo -e "${Error}ERROR ${Off} Failed to download"\
                        "$script-$shorttag.tar.gz!"
                else
                    if [[ -f /tmp/$script-$shorttag.tar.gz ]]; then
                        # Extract tar file to /tmp/<script-name>
                        if ! tar -xf "/tmp/$script-$shorttag.tar.gz" -C "/tmp"; then
                            echo -e "${Error}ERROR ${Off} Failed to"\
                                "extract $script-$shorttag.tar.gz!"
                        else
                            # Copy new script sh files to script location
                            if ! cp -p "/tmp/$script-$shorttag/"*.sh "$scriptpath"; then
                                copyerr=1
                                echo -e "${Error}ERROR ${Off} Failed to copy"\
                                    "$script-$shorttag .sh file(s) to:\n $scriptpath"
                            else                   
                                # Set permsissions on CHANGES.txt
                                if ! chmod 744 "$scriptpath/"*.sh ; then
                                    permerr=1
                                    echo -e "${Error}ERROR ${Off} Failed to set permissions on:"
                                    echo "$scriptpath *.sh file(s)"
                                fi
                            fi

                            # Copy new CHANGES.txt file to script location
                            if ! cp -p "/tmp/$script-$shorttag/CHANGES.txt" "$scriptpath"; then
                                copyerr=1
                                echo -e "${Error}ERROR ${Off} Failed to copy"\
                                    "$script-$shorttag/CHANGES.txt to:\n $scriptpath"
                            else                   
                                # Set permsissions on CHANGES.txt
                                if ! chmod 744 "$scriptpath/CHANGES.txt"; then
                                    permerr=1
                                    echo -e "${Error}ERROR ${Off} Failed to set permissions on:"
                                    echo "$scriptpath/CHANGES.txt"
                                fi
                            fi

                            # Delete downloaded .tar.gz file
                            if ! rm "/tmp/$script-$shorttag.tar.gz"; then
                                delerr=1
                                echo -e "${Error}ERROR ${Off} Failed to delete"\
                                    "downloaded /tmp/$script-$shorttag.tar.gz!"
                            fi

                            # Delete extracted tmp files
                            if ! rm -r "/tmp/$script-$shorttag"; then
                                delerr=1
                                echo -e "${Error}ERROR ${Off} Failed to delete"\
                                    "downloaded /tmp/$script-$shorttag!"
                            fi

                            # Notify of success (if there were no errors)
                            if [[ $copyerr != 1 ]] && [[ $permerr != 1 ]]; then
                                echo -e "\n$tag and changes.txt downloaded to:"\
                                    "$scriptpath"
                                echo -e "${Cyan}Do you want to stop this script"\
                                    "so you can run the new one?${Off} [y/n]"
                                read -r reply
                                if [[ ${reply,,} == "y" ]]; then exit; fi
                            fi
                        fi
                    else
                        echo -e "${Error}ERROR ${Off}"\
                            "/tmp/$script-$shorttag.tar.gz not found!"
                        #ls /tmp | grep "$script"  # debug
                    fi
                fi
            else
                echo -e "${Error}ERROR ${Off} Failed to cd to /tmp!"
            fi
        fi
    fi
fi


#------------------------------------------------------------------------------
# Get list of installed SATA, SAS and M.2 NVMe/SATA drives,
# PCIe M.2 cards and connected Expansion Units.

fixdrivemodel(){
    # Remove " 00Y" from end of Samsung/Lenovo SSDs
    # To fix issue #13
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

getdriveinfo() {
    # Skip removable drives (USB drives)
    # $1 is /sys/block/sata1 etc
    removable=$(cat "$1/removable")  # Some DSM 7 RS models return 1 for internal drives!
    if [[ $removable == "0" ]] || [[ $dsm -gt "6" ]]; then
        # Get drive model and firmware version
        hdmodel=$(cat "$1/device/model")
        hdmodel=$(printf "%s" "$hdmodel" | xargs)  # trim leading and trailing white space

        # Fix dodgy model numbers
        fixdrivemodel "$hdmodel"

        fwrev=$(cat "$1/device/rev")
        fwrev=$(printf "%s" "$fwrev" | xargs)  # trim leading and trailing white space

        if [[ $hdmodel ]] && [[ $fwrev ]]; then
            hdlist+=("${hdmodel},${fwrev}")
        fi
    fi
}

getm2info() {
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

getcardmodel() {
    # Get M.2 card model (if M.2 drives found)
    # $1 is /dev/nvme0n1 etc
    if [[ ${#nvmelist[@]} -gt "0" ]]; then
        cardmodel=$(synodisk --m2-card-model-get "$1")
        if [[ $cardmodel =~ M2D[0-9][0-9] ]]; then
            # M2 adaptor card
            m2carddblist+=("${model}_${cardmodel,,}${version}.db")  # M.2 card's db file
            m2cardlist+=("$cardmodel")                              # M.2 card
        elif [[ $cardmodel =~ E[0-9][0-9]+M.+ ]]; then
            # Ethernet + M2 adaptor card
            m2carddblist+=("${model}_${cardmodel,,}${version}.db")  # M.2 card's db file
            m2cardlist+=("$cardmodel")                              # M.2 card
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
        nvme*)
            if [[ $d =~ nvme[0-9][0-9]?n[0-9][0-9]?$ ]]; then
                if [[ $m2 != "no" ]]; then
                    getm2info "$d" "nvme"
                    # Get M.2 card model if in M.2 card
                    getcardmodel "/dev/$(basename -- "${d}")"
                fi
            fi
        ;;
        nvc*)  # M.2 SATA drives (in PCIe card only?)
            #if [[ $d =~ nvc[0-9][0-9]?p[0-9][0-9]?$ ]]; then
            if [[ $d =~ nvc[0-9][0-9]?$ ]]; then
                if [[ $m2 != "no" ]]; then
                    getm2info "$d" "nvc"
                    # Get M.2 card model if in M.2 card
                    getcardmodel "/dev/$(basename -- "${d}")"
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
    echo -e "${Error}ERROR${Off} No drives found!" && exit 2
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
        echo -e "No M.2 cards found\n"
    else    
        echo "M.2 card models found: ${#m2cards[@]}"
        num="0"
        while [[ $num -lt "${#m2cards[@]}" ]]; do
            echo "${m2cards[num]}"
            num=$((num +1))
        done
        echo
    fi
fi


# Expansion units
# Get list of connected expansion units (aka eunit/ebox)
path="/var/log/diskprediction"
# shellcheck disable=SC2012
file=$(ls $path | tail -n1) 
# shellcheck disable=SC2207
eunitlist=($(grep -Eow "([FRD]XD?[0-9]{3,4})(RP|II|sas){0,2}" "$path/$file" | uniq))

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

db1="/var/lib/disk-compatibility/${model}_host${version}.db"
db2="/var/lib/disk-compatibility/${model}_host${version}.db.new"
dbpath="/var/lib/disk-compatibility/"

synoinfo="/etc.defaults/synoinfo.conf"


if [[ ! -f "$db1" ]]; then echo -e "${Error}ERROR 3${Off} $db1 not found!" && exit 3; fi
#if [[ ! -f "$db2" ]]; then echo -e "${Error}ERROR 4${Off} $db2 not found!" && exit 4; fi
# new installs don't have a .db.new file


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


backupdb() {
    # Backup database file if needed
    if [[ ! -f "$1.bak" ]]; then
        if [[ $(basename "$1") == "synoinfo.conf" ]]; then
            echo "" >&2
        fi
        if cp "$1" "$1.bak"; then
            echo -e "Backed up $(basename -- "${1}")" >&2
        else
            echo -e "${Error}ERROR 5${Off} Failed to backup $(basename -- "${1}")!" >&2
            return 1
        fi
    fi
}


# Backup host database file if needed
backupdb "$db1" || exit 5


#------------------------------------------------------------------------------
# Edit db files

updatedb() {
    hdmodel=$(printf "%s" "$1" | cut -d"," -f 1)
    fwrev=$(printf "%s" "$1" | cut -d"," -f 2)

    #echo arg1 "$1" >&2           # debug
    #echo arg2 "$2" >&2           # debug
    #echo hdmodel "$hdmodel" >&2  # debug
    #echo fwrev "$fwrev" >&2      # debug

    if grep "$hdmodel" "$2" >/dev/null; then
        echo -e "${Yellow}$hdmodel${Off} already exists in ${Cyan}$(basename -- "$2")${Off}" >&2
    else
        # Check if db file is new or old style
        getdbtype "$2"

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

                # Count drives added to host db files
                if [[ $2 == "$db1" ]]; then
                    db1Edits=$((db1Edits +1))
                elif [[ $2 == "$db2" ]]; then
                    db2Edits=$((db2Edits +1))
                fi

            else
                echo -e "\n${Error}ERROR 6${Off} Failed to update v7 $(basename -- "$2")${Off}"
                exit 6
            fi
        elif [[ $dbtype -eq "6" ]];then
            # example:
            # {"model":"WD60EFRX-68MYMN1","firmware":"82.00A82","rec_intvl":[1]},
            # Don't need to add firmware version?
            #string="{\"model\":\"${hdmodel}\",\"firmware\":\"${fwrev}\",\"rec_intvl\":\[1\]},"
            string="{\"model\":\"${hdmodel}\",\"firmware\":\"\",\"rec_intvl\":\[1\]},"
            # {"success":1,"list":[
            startstring="{\"success\":1,\"list\":\["

            #echo "$startstring" >&2  # debug
            #echo "$string" >&2       # debug
            #echo >&2                 # debug

            # example:
            # {"success":1,"list":[{"model":"WD60EFRX-68MYMN1","firmware":"82.00A82","rec_intvl":[1]},
            if sed -ir "s/$startstring/$startstring$string/" "$2"; then
                echo -e "Added ${Yellow}$hdmodel${Off} to ${Cyan}$(basename -- "$2")${Off}"

                # Count drives added to host db files
                if [[ $2 == "$db1" ]]; then
                    db1Edits=$((db1Edits +1))
                elif [[ $2 == "$db2" ]]; then
                    db2Edits=$((db2Edits +1))
                fi

            else
                echo -e "\n${Error}ERROR 8${Off} Failed to update $(basename -- "$2")${Off}" >&2
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

    #------------------------------------------------
    # Expansion Units
    num2="0"
    while [[ $num2 -lt "${#eunits[@]}" ]]; do
        eudb="${dbpath}${eunits[$num2],,}${version}.db"
        if [[ -f "$eudb" ]];then
            backupdb "$eudb" &&\
                updatedb "${hdds[$num]}" "$eudb"
        else
            echo -e "${Error}ERROR 11${Off} $eudb not found!"
        fi
        num2=$((num2 +1))
    done
    #------------------------------------------------

    num=$((num +1))
done

# M.2 NVMe/SATA drives
num="0"
while [[ $num -lt "${#nvmes[@]}" ]]; do
    updatedb "${nvmes[$num]}" "$db1"
    if [[ -f "$db2" ]]; then
        updatedb "${nvmes[$num]}" "$db2"
    fi

    #------------------------------------------------
    # M.2 adaptor cards
    num2="0"
    while [[ $num2 -lt "${#m2carddbs[@]}" ]]; do
        if [[ -f "${dbpath}${m2carddbs[$num2]}" ]];then
            backupdb "${dbpath}${m2carddbs[$num2]}" &&\
                updatedb "${nvmes[$num]}" "${dbpath}${m2carddbs[$num2]}"
        else
            echo -e "${Error}ERROR 10${Off} ${m2carddbs[$num2]} not found!"
        fi
        num2=$((num2 +1))
    done
    #------------------------------------------------

    num=$((num +1))
done


#------------------------------------------------------------------------------
# Edit /etc.defaults/synoinfo.conf

# Backup synoinfo.conf if needed
backupdb "$synoinfo" || exit 9

# Optionally disable "support_disk_compatibility"
sdc=support_disk_compatibility
setting="$(get_key_value $synoinfo $sdc)"
if [[ $force == "yes" ]]; then
    if [[ $setting == "yes" ]]; then
        # Disable support_disk_compatibility
        sed -i "s/${sdc}=\"yes\"/${sdc}=\"no\"/" "$synoinfo"
        setting="$(get_key_value "$synoinfo" $sdc)"
        if [[ $setting == "no" ]]; then
            echo -e "\nDisabled support disk compatibility."
        fi
    fi
else
    if [[ $setting == "no" ]]; then
        # Enable support_disk_compatibility
        sed -i "s/${sdc}=\"no\"/${sdc}=\"yes\"/" "$synoinfo"
        setting="$(get_key_value "$synoinfo" $sdc)"
        if [[ $setting == "yes" ]]; then
            echo -e "\nRe-enabled support disk compatibility."
        fi
    fi
fi


# Optionally disable "support_memory_compatibility"
smc=support_memory_compatibility
setting="$(get_key_value $synoinfo $smc)"
if [[ $ram == "yes" ]]; then
    if [[ $setting == "yes" ]]; then
        # Disable support_memory_compatibility
        sed -i "s/${smc}=\"yes\"/${smc}=\"no\"/" "$synoinfo"
        setting="$(get_key_value "$synoinfo" $smc)"
        if [[ $setting == "no" ]]; then
            echo -e "\nDisabled support memory compatibility."
        fi
    fi
else
    if [[ $setting == "no" ]]; then
        # Enable support_memory_compatibility
        sed -i "s/${smc}=\"no\"/${smc}=\"yes\"/" "$synoinfo"
        setting="$(get_key_value "$synoinfo" $smc)"
        if [[ $setting == "yes" ]]; then
            echo -e "\nRe-enabled support memory compatibility."
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
            # Add support_m2_pool"yes"
            echo 'support_m2_pool="yes"' >> "$synoinfo"
            enabled="yes"
        elif [[ $setting == "no" ]]; then
            # Change support_m2_pool"no" to "yes"
            sed -i "s/${smp}=\"no\"/${smp}=\"yes\"/" "$synoinfo"
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
        echo 'drive_db_test_url="127.0.0.1"' >> "$synoinfo"
        disabled="yes"
    elif [[ $url != "127.0.0.1" ]]; then
        # Edit drive_db_test_url=
        sed -i "s/drive_db_test_url=.*/drive_db_test_url=\"127.0.0.1\"/" "$synoinfo" >/dev/null
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
    fi
else
    # Re-enable drive db updates
    if [[ $url == "127.0.0.1" ]]; then
        # Edit drive_db_test_url=
        sed -z "s/drive_db_test_url=\"127\.0\.0\.1\"\n//" "$synoinfo" >/dev/null
        #sed -i "s/drive_db_test_url=\"127\.0\.0\.1\"//" "$synoinfo"  # works but leaves line feed

        # Check if we re-enabled drive db auto updates
        url="$(get_key_value $synoinfo drive_db_test_url)"
        if [[ $url != "127.0.0.1" ]]; then
            echo -e "\nRe-enabled drive db auto updates."
        fi
    else
        echo -e "\nDrive db auto updates already enabled."
    fi
fi


#------------------------------------------------------------------------------
# Finished

# Show the changes
if [[ ${showedits,,} == "yes" ]]; then
    getdbtype "$db1"
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
    elif [[ $dbtype -eq "6" ]];then
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

