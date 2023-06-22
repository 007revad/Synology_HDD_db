#!/usr/bin/env bash
# shellcheck disable=SC1083,SC2054,SC2121,SC2207
#--------------------------------------------------------------------------------------------------
# Github: https://github.com/007revad/Synology_HDD_db
# Script verified at https://www.shellcheck.net/
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
# sudo -i /volume1/scripts/syno_hdd_db.sh
#  or
# sudo -i /volume1/scripts/syno_hdd_db.sh -showedits
#  or
# sudo -i /volume1/scripts/syno_hdd_db.sh -force -showedits
#--------------------------------------------------------------------------------------------------

# TODO
# Maybe also edit the other disk compatibility db in synoboot, used during boot time.
# It's also parsed and checked and probably in some cases it could be more critical to patch that one instead.
#
# Solve issue of --restore option restoring files that were backed up with older DSM version.

# DONE
# Minor bug fix for checking amount of installed memory.
#
#
# Now enables any installed Synology M.2 PCIe cards for models that don't officially support them.
#
# Added -i, --immutable option to enable immutable snapshots on models older than '20 series running DSM 7.2.
#
# Changed help to show that -r, --ram also sets max memory to the amount of installed memory.
#
# Changed the "No M.2 cards found" to "No M.2 PCIe cards found" to make it clearer.
#
# Added "You may need to reboot" message when NVMe drives were detected.
#
# Fixed HDD/SSD firmware versions always being 4 characters long (for DSM 7.2 and 6.2.4 Update 7).
#
# Fixed detecting the amount of installed memory (for DSM 7.2 which now reports GB instead of MB).
#
# Fixed USB drives sometimes being detected as internal drives (for DSM 7.2).
#
# Fixed error if /run/synostorage/disks/nvme0n1/m2_pool_support doesn't exist yet (for DSM 7.2).
#
# Fixed drive db update still being disabled in /etc/synoinfo.conf after script run without -n or --noupdate option.
#
# Fixed drive db update still being disabled in /etc/synoinfo.conf after script run with --restore option.
#
# Fixed permissions on restored files being incorrect after script run with --restore option.
#
# Fixed permissions on backup files.
#
# Now skips checking the amount of installed memory in DSM 6 (because it was never working).
#
# Now the script reloads itself after updating.
#
# Added --autoupdate=AGE option to auto update synology_hdd_db x days after new version released.
#    Autoupdate logs update success or errors to DSM system log.
#
# Added -w, --wdda option to disable WDDA
#  https://kb.synology.com/en-us/DSM/tutorial/Which_Synology_NAS_supports_WDDA
#  https://www.youtube.com/watch?v=cLGi8sPLkLY
#  https://community.synology.com/enu/forum/1/post/159537
#
#
# Added --restore info to --help
#
# Updated restore option to download the latest db files from Synology
#
# Now warns you if you try to run it in sh with "sh scriptname.sh"
#
# Fixed DSM 6 bug where the drives were being duplicated in the .db files each time the script was run.
#
# Fixed DSM 6 bug where the .db files were being duplicated as .dbr each time the db files were edited.
#
# Fixed bug where expansion units ending in RP or II were not detected.
#
# Added a --restore option to undo all changes.
#
# Now looks for and edits both v7 and non-v7 db files to solve issue #11 for RS '21 models running DSM 6.2.4.
# This will also ensure the script still works if:
#     Synology append different numbers to the db file names in DSM 8 etc.
#     The detected NAS model name does not match the .db files' model name.
#
# Now backs up the .db.new files (as well as the .db files).
#
# Now shows max memory in GB instead of MB.
#
# Now shows status of "Support disk compatibility" setting even if it wasn't changed.
#
# Now shows status of "Support memory compatibility" setting even if it wasn't changed.
#
# Improved shell output when editing max memory setting.
#
# Changed method of checking if drive is a USB drive to prevent ignoring internal drives on RS models.
#
# Changed to not run "synostgdisk --check-all-disks-compatibility" in DSM 6.2.3 (which has no synostgdisk).
#
# Now edits max supported memory to match the amount of memory installed, if greater than the current max memory setting.
#
# Now allows creating M.2 storage pool and volume all from Storage Manager
#
# Now always shows your drive entries in the host db file if -s or --showedits used,
#    instead of only db file was edited during that run.
#
# Changed to show usage if invalid long option used instead of continuing.
#
# Fixed bug inserting firmware version for already existing model.
#
# Changed to add drives' firmware version to the db files (to support data deduplication).
#    See https://github.com/007revad/Synology_enable_Deduplication
#
# Changed to be able to edit existing drive entries in the db files to add the firmware version.
#
# Now supports editing db files that don't currently have any drives listed.
#
# Fixed bug where the --noupdate option was coded as --nodbupdate. Now either will work.
#
# Fixed bug in re-enable drive db updates
#
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


scriptver="v3.0.56"
script=Synology_HDD_db
repo="007revad/Synology_HDD_db"

# Check BASH variable is bash
if [ ! "$(basename "$BASH")" = bash ]; then
    echo "This is a bash script. Do not run it with $(basename "$BASH")"
    printf \\a
    exit 1
fi

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
    restore,showedits,noupdate,nodbupdate,m2,force,ram,wdda,immutable,autoupdate:,help,version,debug \
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
#echo -e "$script $scriptver\ngithub.com/$repo\n"
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

syslog_set(){
    if [[ ${1,,} == "info" ]] || [[ ${1,,} == "warn" ]] || [[ ${1,,} == "err" ]]; then
        if [[ $autoupdate == "yes" ]]; then
            # Add entry to Synology system log
            synologset1 sys "$1" 0x11100000 "$2"
        fi
    fi
}


# Get latest release info
# Curl timeout options:
# https://unix.stackexchange.com/questions/94604/does-curl-have-a-timeout
release=$(curl --silent -m 10 --connect-timeout 5 \
    "https://api.github.com/repos/$repo/releases/latest")

# Release version
tag=$(echo "$release" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
shorttag="${tag:1}"

# Release published date
published=$(echo "$release" | grep '"published_at":' | sed -E 's/.*"([^"]+)".*/\1/')
published="${published:0:10}"
published=$(date -d "$published" '+%s')

# Today's date
now=$(date '+%s')

# Days since release published
age=$(((now - published)/(60*60*24)))


# Get script location
# https://stackoverflow.com/questions/59895/
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
    echo -e "\n${Cyan}There is a newer version of this script available.${Off}"
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
        if [[ $autoupdate == "yes" ]]; then
            if [[ $age -gt "$delay" ]] || [[ $age -eq "$delay" ]]; then
                echo "Downloading $tag"
                reply=y
            else
                echo "Skipping as $tag is less than $delay days old."
            fi
        else
            echo -e "${Cyan}Do you want to download $tag now?${Off} [y/n]"
            read -r -t 30 reply
        fi
        if [[ ${reply,,} == "y" ]]; then
            if cd /tmp; then
                url="https://github.com/$repo/archive/refs/tags/$tag.tar.gz"
                if ! curl -LJO -m 30 --connect-timeout 5 "$url";
                then
                    echo -e "${Error}ERROR ${Off} Failed to download"\
                        "$script-$shorttag.tar.gz!"
                    syslog_set warn "$script $tag failed to download"
                else
                    if [[ -f /tmp/$script-$shorttag.tar.gz ]]; then
                        # Extract tar file to /tmp/<script-name>
                        if ! tar -xf "/tmp/$script-$shorttag.tar.gz" -C "/tmp"; then
                            echo -e "${Error}ERROR ${Off} Failed to"\
                                "extract $script-$shorttag.tar.gz!"
                            syslog_set warn "$script failed to extract $script-$shorttag.tar.gz!"
                        else
                            # Copy new script sh files to script location
                            if ! cp -p "/tmp/$script-$shorttag/"*.sh "$scriptpath"; then
                                copyerr=1
                                echo -e "${Error}ERROR ${Off} Failed to copy"\
                                    "$script-$shorttag .sh file(s) to:\n $scriptpath"
                                syslog_set warn "$script failed to copy $tag to script location"
                            else                   
                                # Set permissions on script sh files
                                if ! chmod 744 "$scriptpath/"*.sh ; then
                                    permerr=1
                                    echo -e "${Error}ERROR ${Off} Failed to set permissions on:"
                                    echo "$scriptpath *.sh file(s)"
                                    syslog_set warn "$script failed to set permissions on $tag"
                                fi
                            fi

                            # Copy new CHANGES.txt file to script location
                            if ! cp -p "/tmp/$script-$shorttag/CHANGES.txt" "$scriptpath"; then
                                if [[ $autoupdate != "yes" ]]; then copyerr=1; fi
                                echo -e "${Error}ERROR ${Off} Failed to copy"\
                                    "$script-$shorttag/CHANGES.txt to:\n $scriptpath"
                            else                   
                                # Set permissions on CHANGES.txt
                                if ! chmod 744 "$scriptpath/CHANGES.txt"; then
                                    if [[ $autoupdate != "yes" ]]; then permerr=1; fi
                                    echo -e "${Error}ERROR ${Off} Failed to set permissions on:"
                                    echo "$scriptpath/CHANGES.txt"
                                fi
                            fi

                            # Delete downloaded .tar.gz file
                            if ! rm "/tmp/$script-$shorttag.tar.gz"; then
                                echo -e "${Error}ERROR ${Off} Failed to delete"\
                                    "downloaded /tmp/$script-$shorttag.tar.gz!"
                                syslog_set warn "$script update failed to delete tmp files"
                            fi

                            # Delete extracted tmp files
                            if ! rm -r "/tmp/$script-$shorttag"; then
                                echo -e "${Error}ERROR ${Off} Failed to delete"\
                                    "downloaded /tmp/$script-$shorttag!"
                                syslog_set warn "$script update failed to delete tmp files"
                            fi

                            # Notify of success (if there were no errors)
                            if [[ $copyerr != 1 ]] && [[ $permerr != 1 ]]; then
                                echo -e "\n$tag and changes.txt downloaded to: ${scriptpath}\n"
                                syslog_set info "$script successfully updated to $tag"

                                # Reload script
                                printf -- '-%.0s' {1..79}; echo  # print 79 -
                                exec "$0" "${args[@]}"
                            else
                                syslog_set warn "$script update to $tag had errors"
                            fi
                        fi
                    else
                        echo -e "${Error}ERROR ${Off}"\
                            "/tmp/$script-$shorttag.tar.gz not found!"
                        #ls /tmp | grep "$script"  # debug
                        syslog_set warn "/tmp/$script-$shorttag.tar.gz not found"
                    fi
                fi
            else
                echo -e "${Error}ERROR ${Off} Failed to cd to /tmp!"
                syslog_set warn "$script update failed to cd to /tmp"
            fi
        fi
    fi
fi


#------------------------------------------------------------------------------
# Restore changes from backups

dbpath=/var/lib/disk-compatibility/
synoinfo="/etc.defaults/synoinfo.conf"

if [[ $restore == "yes" ]]; then
    dbbakfiles=($(find $dbpath -maxdepth 1 \( -name "*.db.new.bak" -o -name "*.db.bak" \)))
    echo

    if [[ ${#dbbakfiles[@]} -gt "0" ]] || [[ -f ${synoinfo}.bak ]]; then

        # Restore synoinfo.conf from backup
        if [[ -f ${synoinfo}.bak ]]; then
            #if mv "${synoinfo}.bak" "${synoinfo}"; then
            if cp -p "${synoinfo}.bak" "${synoinfo}"; then
                echo -e "Restored $(basename -- "$synoinfo")\n"
            else
                restoreerr=1
                echo -e "${Error}ERROR${Off} Failed to restore synoinfo.conf!\n"
            fi
        fi

        # Restore .db files from backups
        for f in "${!dbbakfiles[@]}"; do
            replaceme="${dbbakfiles[f]%.bak}"  # Remove .bak
            #if mv "${dbbakfiles[f]}" "$replaceme"; then
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
        #fwrev=$(syno_hdd_util --ssd_detect | grep "$device" | awk '{print $2}')      # GitHub issue #86, 87
        # Account for SSD drives with spaces in their model name/number
        fwrev=$(syno_hdd_util --ssd_detect | grep "$device" | awk '{print $(NF-3)}')  # GitHub issue #86, 87

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
        echo -e "${Error}ERROR 5${Off} Failed to backup $(basename -- "${db1list[i]}")!"
        exit 5
        }
done
for i in "${!db2list[@]}"; do
    backupdb "${db2list[i]}" ||{
        ding
        echo -e "${Error}ERROR 5${Off} Failed to backup $(basename -- "${db2list[i]}")!"
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

enable_card(){
    if [[ -f $1 ]] && [[ -n $2 ]]; then
        # Check if section exists
        if ! grep '^\['"$2"'\]$' "$1"; then
            echo -e "Section [$2] not found in $(basename -- "$1")!" >&2
            return
        fi
        # Check if already enabled
        val=$(get_section_key_value "$1" "$2" "$modelname")
        if [[ $val != "yes" ]]; then
            if set_section_key_value "$1" "$2" "$modelname" yes; then
                echo -e "Enabled $1 for $modelname" >&2
            else
                echo -e "${Error}ERROR 5${Off} Failed to enable $1 for ${modelname}!" >&2
            fi
        else
            echo -e "$1 already enabled for $modelname" >&2
        fi
    fi
}

for c in "${!m2cards[@]}"; do
    echo ""
    m2cardconf="/usr/syno/etc.defaults/adapter_cards.conf"
    case "$c" in
        E10M20-T1)
            enable_card "$m2cardconf" E10M20-T1_sup_nvme
            enable_card "$m2cardconf" E10M20-T1_sup_sata
        ;;
        M2D20)
            enable_card "$m2cardconf" M2D20_sup_nvme
        ;;
        M2D18)
            enable_card "$m2cardconf" M2D18_sup_nvme
            enable_card "$m2cardconf" M2D18_sup_sata
        ;;
        M2D17)
            enable_card "$m2cardconf" M2D17_sup_sata
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


# Optionally disable "support_memory_compatibility"
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

# Optionally set mem_max_mb to the amount of installed memory
if [[ $dsm -gt "6" ]]; then  # DSM 6 as has no /proc/meminfo
    if [[ $ram == "yes" ]]; then
        # Get total amount of installed memory
        IFS=$'\n' read -r -d '' -a array < <(dmidecode -t memory | grep "[Ss]ize")  # GitHub issue #86, 87
        if [[ ${#array[@]} -gt "0" ]]; then
            num="0"
            while [[ $num -lt "${#array[@]}" ]]; do
                check=$(printf %s "${array[num]}" | awk '{print $1}')
                if [[ ${check,,} == "size:" ]]; then
                    #ramsize=$(printf %s "${array[num]}" | cut -d" " -f2)
                    ramsize=$(printf %s "${array[num]}" | awk '{print $2}')           # GitHub issue #86, 87
                    bytes=$(printf %s "${array[num]}" | awk '{print $3}')             # GitHub issue #86, 87
                    if [[ $ramsize =~ ^[0-9]+$ ]]; then  # Check $ramsize is numeric  # GitHub issue #86, 87
                        if [[ $ramtotal ]]; then
                            ramtotal=$((ramtotal +ramsize))
                        else
                            ramtotal="$ramsize"
                        fi
                    #else
                    #    echo -e "\n${Error}ERROR${Off} Memory size is not numeric: '$ramsize'"
                    fi
                fi
                num=$((num +1))
            done
        fi
        # Set mem_max_mb to the amount of installed memory
        setting="$(get_key_value $synoinfo mem_max_mb)"
        if [[ $ramtotal =~ ^[0-9]+$ ]]; then   # Check $ramtotal is numeric
            if [[ $bytes == "GB" ]]; then      # DSM 7.2 dmidecode returns GB
                ramtotal=$((ramtotal * 1024))  # Convert to MB
            fi
            if [[ $ramtotal -gt $setting ]]; then
                synosetkeyvalue "$synoinfo" mem_max_mb "$ramtotal"
                # Check we changed mem_max_mb
                setting="$(get_key_value $synoinfo mem_max_mb)"
                if [[ $setting == "$ramtotal" ]]; then
                    #echo -e "\nSet max memory to $ramtotal MB."
                    ramgb=$((ramtotal / 1024))
                    echo -e "\nSet max memory to $ramtotal GB."
                else
                    echo -e "\n${Error}ERROR${Off} Failed to change max memory!"
                fi
            elif [[ $setting == "$ramtotal" ]]; then
                #echo -e "\nMax memory already set to $ramtotal MB."
                ramgb=$((ramtotal / 1024))
                echo -e "\nMax memory already set to $ramgb GB."
            else [[ $setting -lt "$ramtotal" ]]
                #echo -e "\nMax memory is set to $ramtotal MB."
                ramgb=$((ramtotal / 1024))
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

