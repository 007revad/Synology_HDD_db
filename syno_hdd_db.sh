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
# Change how synoinfo.conf is backed up and restored to prevent issue #73

# DONE
# Updated so E10M20-T1, M2D20 and M2D18 now work in models that use device tree,
# and are using DSM 7.2 Update 2, Update 3, 7.2.1 and 7.2.1 Update 1.
#
# Fixed bug where memory was shown in MB but with GB unit. 
#
#
# Bug fix for script not updating itself if .sh file had been renamed.
#
# Bug fix for missing executable permissions if .sh file had been renamed.
#
# Bug fix to prevent update loop if script's .tar.gz file already exists in /tmp.
#
# Bug fix to prevent update failing if script's temp folder already exists in /tmp.
#
# Now only copies CHANGES.txt to script location if script is located on a volume,
# to prevent putting CHANGES.txt on system partition (/usr/bin, /usr/sbin, /root etc.)
#
# Added -e --email option to disable coloured output to make task scheduler emails easier to read.
#
#
# Added support to disable unsupported memory warnings on DVA models.
#
# Fixed bug where newly connected expansion units weren't found until up to 24 hours later. #124
#
# Added enabling E10M20-T1, M2D20 and M2D18 for DS1821+, DS1621+ and DS1520+.
# Added enabling M2D18 for RS822RP+, RS822+, RS1221RP+ and RS1221+ with older DSM version.
#
# Fixed enabling E10M20-T1, M2D20 and M2D18 cards in models that don't officially support them.
#
# Enable NVMe drive use for models that do not have NVMe drives enabled.
#
# Fixed bugs where the calculated amount of installed memory could be incorrect:
#   - If last memory socket was empty an invalid unit of bytes could be used. Issue #106
#   - When dmidecode returned MB for one ram module and GB for another ram module. Issue #107
#
# Fixed bug displaying the max memory setting if total installed memory was less than the max memory. Issue #107
#
# Fixed bug where sata1 drive firmware version was wrong if there was a sata10 drive.
#
# Minor bug fix for checking amount of installed memory.
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


scriptver="v3.2.66"
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
                immutable=yes   # Does not work for models without support_worm=yes already
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
scriptfile=$( basename -- "$source" )
echo "Running from: ${scriptpath}/$scriptfile"

#echo "Script location: $scriptpath"  # debug
#echo "Source: $source"               # debug
#echo "Script filename: $scriptfile"  # debug

#echo "tag: $tag"              # debug
#echo "scriptver: $scriptver"  # debug


cleanup_tmp(){ 
    cleanup_err=

    # Delete downloaded .tar.gz file
    if [[ -f "/tmp/$script-$shorttag.tar.gz" ]]; then
        if ! rm "/tmp/$script-$shorttag.tar.gz"; then
            echo -e "${Error}ERROR${Off} Failed to delete"\
                "downloaded /tmp/$script-$shorttag.tar.gz!" >&2
            cleanup_err=1
        fi
    fi

    # Delete extracted tmp files
    if [[ -d "/tmp/$script-$shorttag" ]]; then
        if ! rm -r "/tmp/$script-$shorttag"; then
            echo -e "${Error}ERROR${Off} Failed to delete"\
                "downloaded /tmp/$script-$shorttag!" >&2
            cleanup_err=1
        fi
    fi

    # Add warning to DSM log
    if [[ -z $cleanup_err ]]; then
        syslog_set warn "$script update failed to delete tmp files"
    fi
}


if ! printf "%s\n%s\n" "$tag" "$scriptver" |
        sort --check=quiet --version-sort >/dev/null ; then
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
            # Delete previously downloaded .tar.gz file and extracted tmp files
            cleanup_tmp

            if cd /tmp; then
                url="https://github.com/$repo/archive/refs/tags/$tag.tar.gz"
                if ! curl -JLO -m 30 --connect-timeout 5 "$url"; then
                    echo -e "${Error}ERROR${Off} Failed to download"\
                        "$script-$shorttag.tar.gz!"
                    syslog_set warn "$script $tag failed to download"
                else
                    if [[ -f /tmp/$script-$shorttag.tar.gz ]]; then
                        # Extract tar file to /tmp/<script-name>
                        if ! tar -xf "/tmp/$script-$shorttag.tar.gz" -C "/tmp"; then
                            echo -e "${Error}ERROR${Off} Failed to"\
                                "extract $script-$shorttag.tar.gz!"
                            syslog_set warn "$script failed to extract $script-$shorttag.tar.gz!"
                        else
                            # Set permissions on script sh files
                            if ! chmod a+x "/tmp/$script-$shorttag/"*.sh ; then
                                permerr=1
                                echo -e "${Error}ERROR${Off} Failed to set executable permissions"
                                syslog_set warn "$script failed to set permissions on $tag"
                            fi

                            # Copy new script sh file to script location
                            if ! cp -p "/tmp/$script-$shorttag/syno_hdd_db.sh" "${scriptpath}/${scriptfile}";
                            then
                                copyerr=1
                                echo -e "${Error}ERROR${Off} Failed to copy"\
                                    "$script-$shorttag .sh file(s) to:\n $scriptpath"
                                syslog_set warn "$script failed to copy $tag to script location"
                            fi

                            # Copy new CHANGES.txt file
                            if [[ $scriptpath =~ /volume* ]]; then
                                # Copy new CHANGES.txt file to script location
                                if ! cp -p "/tmp/$script-$shorttag/CHANGES.txt" "$scriptpath"; then
                                    if [[ $autoupdate != "yes" ]]; then copyerr=1; fi
                                    echo -e "${Error}ERROR${Off} Failed to copy"\
                                        "$script-$shorttag/CHANGES.txt to:\n $scriptpath"
                                else
                                    # Set permissions on CHANGES.txt
                                    if ! chmod 664 "$scriptpath/CHANGES.txt"; then
                                        if [[ $autoupdate != "yes" ]]; then permerr=1; fi
                                        echo -e "${Error}ERROR${Off} Failed to set permissions on:"
                                        echo "$scriptpath/CHANGES.txt"
                                    fi
                                    changestxt=" and changes.txt"
                                fi
                            fi

                            # Delete downloaded .tar.gz file and extracted tmp files
                            cleanup_tmp

                            # Notify of success (if there were no errors)
                            if [[ $copyerr != 1 ]] && [[ $permerr != 1 ]]; then
                                echo -e "\n$tag$changestxt downloaded to: ${scriptpath}\n"
                                syslog_set info "$script successfully updated to $tag"

                                # Reload script
                                printf -- '-%.0s' {1..79}; echo  # print 79 -
                                exec "$0" "${args[@]}"
                            else
                                syslog_set warn "$script update to $tag had errors"
                            fi
                        fi
                    else
                        echo -e "${Error}ERROR${Off}"\
                            "/tmp/$script-$shorttag.tar.gz not found!"
                        #ls /tmp | grep "$script"  # debug
                        syslog_set warn "/tmp/$script-$shorttag.tar.gz not found"
                    fi
                fi
                cd "$scriptpath" || echo -e "${Error}ERROR${Off} Failed to cd to script location!"
            else
                echo -e "${Error}ERROR${Off} Failed to cd to /tmp!"
                syslog_set warn "$script update failed to cd to /tmp"
            fi
        fi
    fi
fi


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
    if [[ $1 =~ MZ.*" 00Y" ]]; then
        echo 
    fi
    if [[ $1 =~ ^[A-Za-z]{1,7}" ".* ]]; then
	echo 
    fi
}

getdriveinfo(){ 
    # $1 is /sys/block/sata1 etc
    usb=$(grep "$(basename -- "$1")" /proc/mounts | grep "[Uu][Ss][Bb]" | cut -d" " -f1-2)
    if [[ ! $usb ]]; then  # Skip USB drives

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
    isinm2card=""
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
            isinm2card="yes"
        elif [[ $cardmodel =~ E[0-9][0-9]+M.+ ]]; then
            # Ethernet + M2 adaptor card
            if [[ -f "${model}_${cardmodel,,}${version}.db" ]]; then
                m2carddblist+=("${model}_${cardmodel,,}${version}.db")  # M.2 card's db file
            fi
            if [[ -f "${model}_${cardmodel,,}.db" ]]; then
                m2carddblist+=("${model}_${cardmodel,,}.db")            # M.2 card's db file
            fi
            m2cardlist+=("$cardmodel")                                  # M.2 card
            isinm2card="yes"
        fi
    fi
}

m2_pool_support(){ 
    if [[ $isinm2card != "yes" ]]; then
        if [[ -f /run/synostorage/disks/"$(basename -- "$1")"/m2_pool_support ]]; then  # GitHub issue #86, 87
            echo 1 > /run/synostorage/disks/"$(basename -- "$1")"/m2_pool_support
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


dts_m2_card(){ 
# $1 is the card model
# $2 is the dts file

# Remove last }; so we can append to dts file
sed -i '/^};/d' "$2"

# Append PCIe M.2 card node to dts file
if [[ $1 == E10M20-T1 ]] || [[ $1 == M2D20 ]]; then
    cat >> "$2" <<EOM2D

	$1 {
		compatible = "Synology";
		model = "synology_${1,,}";

		m2_card@1 {

			nvme {
				pcie_postfix = "00.0,08.0,00.0";
				port_type = "ssdcache";
			};
		};

		m2_card@2 {

			nvme {
				pcie_postfix = "00.0,04.0,00.0";
				port_type = "ssdcache";
			};
		};
	};
};
EOM2D

elif [[ $1 == M2D18 ]]; then
    cat >> "$2" <<EOM2D18

	M2D18 {
		compatible = "Synology";
		model = "synology_m2d18";

		m2_card@1 {

			ahci {
				pcie_postfix = "00.0,03.0,00.0";
				ata_port = <0x00>;
			};

			nvme {
				pcie_postfix = "00.0,04.0,00.0";
				port_type = "ssdcache";
			};
		};

		m2_card@2 {

			ahci {
				pcie_postfix = "00.0,03.0,00.0";
				ata_port = <0x01>;
			};

			nvme {
				pcie_postfix = "00.0,05.0,00.0";
				port_type = "ssdcache";
			};
		};
	};
};
EOM2D18

fi
}


download_dtc(){ 
    # Download dtc from github
    echo "Downloading dtc" >&2
    if cd /var/services/tmp; then
        url="https://github.com/${repo}/raw/main/bin/dtc"
        #if curl -kLJO -m 30 --connect-timeout 5 "$url"; then
        if curl -kLO -m 30 --connect-timeout 5 "$url"; then
            mv /var/services/tmp/dtc /usr/sbin/dtc
            chmod 755 /usr/sbin/dtc
        fi
    else
        echo -e "${Error}ERROR${Off} Failed to cd to /var/services/tmp!" >&2
    fi
}


edit_dts(){ 

#set -x  # debug

    # $1 is M.2 card model
    # Edit model.dts if needed
    if ! grep "$1" "$dtb_file" >/dev/null; then
        dts_m2_card "$1" "$dts_file"
        #echo "Added $1 to model${hwrev}.dtb" >&2
        echo -e "Added ${Yellow}$1${Off} to ${Cyan}model${hwrev}.dtb${Off}" >&2
#    else
        #echo "$1 already exists in model${hwrev}.dtb" >&2
#        echo -e "${Yellow}$1${Off} already exists in ${Cyan}model${hwrev}.dtb${Off}" >&2
    fi

#set +x  # debug

}


set_pwr_limit(){ 
    if ! grep "$pwr_limit" "$dts_file" >/dev/null; then
        # Save current power_limit
        pwr_lmt_old=$(grep power_limit "$dts_file" | cut -d\" -f2)

        # Find line to insert power_limit
        pwrlim_line=$(awk '! NF { print NR }' "$dts_file" | head -n 2 | tail -n 1)

        power_limit="	power_limit = \"$pwr_limit\";"
        #echo "$power_limit" >&2  # debug

        if grep power_limit "$dts_file" >/dev/null; then
            filehead=$(head -n $((pwrlim_line -2)) "$dts_file")
        else
            filehead=$(head -n $((pwrlim_line -1)) "$dts_file")
        fi
        #echo "$filehead" >&2  # debug

        filetail=$(tail -n +$((pwrlim_line +1)) "$dts_file")
        #echo "$filetail" >&2  # debug

        echo "$filehead" > "$dts_file"
        echo -e "$power_limit\n" >> "$dts_file"
        echo "$filetail" >> "$dts_file"

        # Show result
        echo -e "Updated power limit in ${Cyan}model${hwrev}.dtb${Off}" >&2
        echo "  Old power_limit $pwr_lmt_old" >&2
        echo "  New power_limit $pwr_limit" >&2
    fi
}


check_modeldtb(){ 
    # $1 is E10M20-T1 or M2D20 or M2D18 or M2D17
    if [[ -f /etc.defaults/model.dtb ]]; then  # Is device tree model
        # Get syn_hw_revision, r1 or r2 etc (or just a linefeed if not a revision)
        hwrevision=$(cat /proc/sys/kernel/syno_hw_revision)

        # If syno_hw_revision is r1 or r2 it's a real Synology,
        # and I need to edit model_rN.dtb instead of model.dtb
        if [[ $hwrevision =~ r[0-9] ]]; then
            #echo "hwrevision: $hwrevision" >&2  # debug
            hwrev="_$hwrevision"
        fi


        dtb_file="/etc.defaults/model${hwrev}.dtb"
        dts_file="/etc.defaults/model${hwrev}.dts"
        dtb2_file="/etc/model${hwrev}.dtb"


        # NVMe power_limit
        if grep power_limit /run/model.dtb >/dev/null; then

            if [ -f /sys/firmware/devicetree/base/power_limit ]; then
                pwrval=$(cat /sys/firmware/devicetree/base/power_limit | cut -d"," -f1)
                # Check pwrval is float or numeric
                if [[ ! $pwrval =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                    pwrval="100"
                fi
            else
                pwrval="100"
            fi

            pwr_limit=""
            nvme_drives=$(ls /sys/class/nvme | wc -w)
            for i in $(seq 0 $((nvme_drives -1))); do 
                [ "$i" -eq 0 ] && pwr_limit="$pwrval" || pwr_limit="${pwr_limit},$pwrval"
            done

            #echo "power_limit $pwr_limit" >&2  # debug
        fi

        # Check power_limit and adapter card already in model.dtb
        if grep "$pwr_limit" "$dtb_file" >/dev/null && grep "$1" "$dtb_file" >/dev/null
        then
            echo -e "${Yellow}$1${Off} already exists in ${Cyan}model${hwrev}.dtb${Off}" >&2
            return
        fi


        # Check if dtc exists and is executable
        if [[ ! -x /usr/sbin/dtc ]]; then
            if [[ -f ./bin/dtc ]]; then
                cp -f ./bin/dtc /usr/sbin/dtc
                chmod 755 /usr/sbin/dtc
            else
                download_dtc
            fi
        fi

        # Check again if dtc exists and is executable
        if [[ -x /usr/sbin/dtc ]]; then

            # Backup model.dtb
            if ! backupdb "$dtb_file"; then
                echo -e "${Error}ERROR${Off} Failed to backup ${dtb_file}!" >&2
            fi

            # Output model.dtb to model.dts
            dtc -q -I dtb -O dts -o "$dts_file" "$dtb_file"  # -q Suppress warnings
            chmod 644 "$dts_file"

            # Edit model.dts
            #edit_dts "E10M20-T1"  # test
            #edit_dts "M2D20"      # test
            #edit_dts "M2D18"      # test
            edit_dts "$1"

            [[ -n $pwr_limit ]] && set_pwr_limit

            # Compile model.dts to model.dtb
            dtc -q -I dts -O dtb -o "$dtb_file" "$dts_file"  # -q Suppress warnings

            # Set owner and permissions for model.dtb
            chmod a+r "$dtb_file"
            chown root:root "$dtb_file"
            cp -pu "$dtb_file" "$dtb2_file"  # Copy dtb file to /etc

            # Delete model.dts
            rm  "$dts_file"
        else
            echo -e "${Error}ERROR${Off} Missing /usr/sbin/dtc or not executable!" >&2
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
            #enable_card "$m2cardconf" E10M20-T1_sup_sata "E10M20-T1 SATA"
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

# Disable SynoMemCheck.service for DVA models
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
                    echo -e "\nSet max memory to $ramgb GB."
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
                    echo -e "\nRestored max memory to $ramgb GB."
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



# Enable nvme support                   This probably should be before we look for NVMe drives.
#                                       But it probably also needs a reboot after we change it.
if [[ $m2 != "no" ]]; then
    # Check if nvme support is enabled
    setting="$(get_key_value $synoinfo supportnvme)"
    enabled=""
    if [[ ! $setting ]]; then
        # Add supportnvme="yes"
        synosetkeyvalue "$synoinfo" supportnvme "yes"
        enabled="yes"
    elif [[ $setting == "no" ]]; then
        # Change supportnvme="no" to "yes"
        synosetkeyvalue "$synoinfo" supportnvme "yes"
        enabled="yes"
    elif [[ $setting == "yes" ]]; then
        echo -e "\nNVMe support already enabled."
    fi

    # Check if we enabled nvme support
    setting="$(get_key_value $synoinfo supportnvme)"
    if [[ $enabled == "yes" ]]; then
        if [[ $setting == "yes" ]]; then
            echo -e "\nEnabled NVMe support."
        else
            echo -e "\n${Error}ERROR${Off} Failed to enable NVMe support!"
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

