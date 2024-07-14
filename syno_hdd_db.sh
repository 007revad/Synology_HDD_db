#!/usr/bin/env bash
# shellcheck disable=SC1083,SC2054,SC2121,SC2207
#--------------------------------------------------------------------------------------------------
# Github: https://github.com/007revad/Synology_HDD_db
# Script verified at https://www.shellcheck.net/
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
# https://smarthdd.com/database/

# RECENT CHANGES

# TODO
# Enable SMART Attributes button on Storage Manager
# disabled:e.healthInfoDisabled
# enabled:e.healthInfoDisabled
# /var/packages/StorageManager/target/ui/storage_panel.js


scriptver="v3.5.94"
script=Synology_HDD_db
repo="007revad/Synology_HDD_db"
scriptname=syno_hdd_db

# Check BASH variable is bash
if [ ! "$(basename "$BASH")" = bash ]; then
    echo "This is a bash script. Do not run it with $(basename "$BASH")"
    printf \\a
    exit 1
fi

# Check script is running on a Synology NAS
if ! /usr/bin/uname -a | grep -i synology >/dev/null; then
    echo "This script is NOT running on a Synology NAS!"
    echo "Copy the script to a folder on the Synology"
    echo "and run it from there."
    exit 1
fi

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
  -r, --ram             Disable memory compatibility checking (DSM 7.x only)
                        and sets max memory to the amount of installed memory
  -f, --force           Force DSM to not check drive compatibility
                        Do not use this option unless absolutely needed
  -i, --incompatible    Change incompatible drives to supported
                        Do not use this option unless absolutely needed
  -w, --wdda            Disable WD Device Analytics to prevent DSM showing
                        a false warning for WD drives that are 3 years old
                          DSM 7.2.1 already has WDDA disabled
  -p, --pcie            Enable creating volumes on M2 in unknown PCIe adaptor
  -e, --email           Disable colored text in output scheduler emails
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
    restore,showedits,noupdate,nodbupdate,m2,force,incompatible,ram,pcie,wdda,email,autoupdate:,help,version,debug \
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
            -i|--incompatible)  # Change incompatible drives to supported
                incompatible=yes
                ;;
            -r|--ram)           # Disable "support_memory_compatibility"
                ram=yes
                ;;
            -w|--wdda)          # Disable "support_wdda"
                wdda=no
                ;;
            -p|--pcie)          # Enable creating volumes on M2 in unknown PCIe adaptor
                forcepci=yes
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
    set -x
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
    echo -e "${Error}ERROR${Off} This script must be run as sudo or root!"
    exit 1
fi

# Get DSM major version
dsm=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION majorversion)
if [[ $dsm -gt "6" ]]; then
    version="_v$dsm"
fi

# Get Synology model
model=$(cat /proc/sys/kernel/syno_hw_version)
modelname="$model"


# Show script version
#echo -e "$script $scriptver\ngithub.com/$repo\n"
echo "$script $scriptver"

# Get DSM full version
productversion=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION productversion)
buildphase=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION buildphase)
buildnumber=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION buildnumber)
smallfixnumber=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION smallfixnumber)

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

# Get StorageManager version
storagemgrver=$(/usr/syno/bin/synopkg version StorageManager)
# Show StorageManager version
if [[ $storagemgrver ]]; then echo -e "StorageManager $storagemgrver\n"; fi

# Show host drive db version
if [[ -f "/var/lib/disk-compatibility/${model}_host_v7.version" ]]; then
    echo -n "${model}_host_v7 version "
    cat "/var/lib/disk-compatibility/${model}_host_v7.version"
    echo -e "\n"
fi
if [[ -f "/var/lib/disk-compatibility/${model}_host.version" ]]; then
    echo -n "${model}_host version "
    cat "/var/lib/disk-compatibility/${model}_host.version"
    echo -e "\n"
fi


# Show options used
if [[ ${#args[@]} -gt "0" ]]; then
    echo "Using options: ${args[*]}"
fi

#echo ""  # To keep output readable


# shellcheck disable=SC2317  # Don't warn about unreachable commands in this function
pause(){ 
    # When debugging insert pause command where needed
    read -s -r -n 1 -p "Press any key to continue..."
    read -r -t 0.1 -s -e --  # Silently consume all input
    stty echo echok  # Ensure read didn't disable echoing user input
    echo -e "\n"
}


#------------------------------------------------------------------------------
# Check latest release with GitHub API

syslog_set(){ 
    if [[ ${1,,} == "info" ]] || [[ ${1,,} == "warn" ]] || [[ ${1,,} == "err" ]]; then
        if [[ $autoupdate == "yes" ]]; then
            # Add entry to Synology system log
            /usr/syno/bin/synologset1 sys "$1" 0x11100000 "$2"
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


# Warn if script located on M.2 drive
scriptvol=$(echo "$scriptpath" | cut -d"/" -f2)
vg=$(lvdisplay | grep /volume_"${scriptvol#volume}" | cut -d"/" -f3)
md=$(pvdisplay | grep -B 1 -E '[ ]'"$vg" | grep /dev/ | cut -d"/" -f3)
# shellcheck disable=SC2002  # Don't warn about "Useless cat"
if cat /proc/mdstat | grep "$md" | grep nvme >/dev/null; then
    echo -e "\n${Yellow}WARNING${Off} Don't store this script on an NVMe volume!"
fi


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
    if [[ $cleanup_err ]]; then
        syslog_set warn "$script update failed to delete tmp files"
    fi
}


if ! printf "%s\n%s\n" "$tag" "$scriptver" |
        sort --check=quiet --version-sort >/dev/null ; then
    echo -e "\n${Cyan}There is a newer version of this script available.${Off}"
    echo -e "Current version: ${scriptver}\nLatest version:  $tag"
    scriptdl="$scriptpath/$script-$shorttag"
    if [[ -f ${scriptdl}.tar.gz ]] || [[ -f ${scriptdl}.zip ]]; then
        # They have the latest version tar.gz downloaded but are using older version
        echo "You have the latest version downloaded but are using an older version"
        sleep 10
    elif [[ -d $scriptdl ]]; then
        # They have the latest version extracted but are using older version
        echo "You have the latest version extracted but are using an older version"
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
                            # Set script sh files as executable
                            if ! chmod a+x "/tmp/$script-$shorttag/"*.sh ; then
                                permerr=1
                                echo -e "${Error}ERROR${Off} Failed to set executable permissions"
                                syslog_set warn "$script failed to set permissions on $tag"
                            fi

                            # Copy new script sh file to script location
                            if ! cp -p "/tmp/$script-$shorttag/${scriptname}.sh" "${scriptpath}/${scriptfile}";
                            then
                                copyerr=1
                                echo -e "${Error}ERROR${Off} Failed to copy"\
                                    "$script-$shorttag sh file(s) to:\n $scriptpath/${scriptfile}"
                                syslog_set warn "$script failed to copy $tag to script location"
                            fi

                            # Copy new syno_hdd_vendor_ids.txt file
                            vidstxt="syno_hdd_vendor_ids.txt"
                            if [[ $scriptpath =~ /volume* ]]; then
                                if [[ ! -f "$scriptpath/$vidstxt" ]]; then  # Don't overwrite file
                                    # Copy new syno_hdd_vendor_ids.txt file to script location
                                    if ! cp -p "/tmp/$script-$shorttag/$vidstxt" "$scriptpath"; then
                                        if [[ $autoupdate != "yes" ]]; then copyerr=1; fi
                                        echo -e "${Error}ERROR${Off} Failed to copy"\
                                            "$script-$shorttag/$vidstxt to:\n $scriptpath"
                                    else
                                        # Set permissions on syno_hdd_vendor_ids.txt
                                        if ! chmod 755 "$scriptpath/$vidstxt"; then
                                            if [[ $autoupdate != "yes" ]]; then permerr=1; fi
                                            echo -e "${Error}ERROR${Off} Failed to set permissions on:"
                                            echo "$scriptpath/$vidstxt"
                                        fi
                                        vids_txt=", syno_hdd_vendor_ids.txt"
                                    fi
                                fi
                            fi

                            # Copy new CHANGES.txt file to script location (if script on a volume)
                            if [[ $scriptpath =~ /volume* ]]; then
                                # Set permissions on CHANGES.txt
                                if ! chmod 664 "/tmp/$script-$shorttag/CHANGES.txt"; then
                                    permerr=1
                                    echo -e "${Error}ERROR${Off} Failed to set permissions on:"
                                    echo "$scriptpath/CHANGES.txt"
                                fi

                                # Copy new CHANGES.txt file to script location
                                if ! cp -p "/tmp/$script-$shorttag/CHANGES.txt"\
                                    "${scriptpath}/${scriptname}_CHANGES.txt";
                                then
                                    if [[ $autoupdate != "yes" ]]; then copyerr=1; fi
                                    echo -e "${Error}ERROR${Off} Failed to copy"\
                                        "$script-$shorttag/CHANGES.txt to:\n $scriptpath"
                                else
                                    changestxt=" and changes.txt"
                                fi
                            fi

                            # Delete downloaded tmp files
                            cleanup_tmp

                            # Notify of success (if there were no errors)
                            if [[ $copyerr != 1 ]] && [[ $permerr != 1 ]]; then
                                echo -e "\n$tag ${scriptfile}$vids_txt$changestxt downloaded to: ${scriptpath}\n"
                                syslog_set info "$script successfully updated to $tag"

                                # Reload script
                                printf -- '-%.0s' {1..79}; echo  # print 79 -
                                exec "${scriptpath}/$scriptfile" "${args[@]}"
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
# Set file variables

if [[ -f /etc.defaults/model.dtb ]]; then  # Is device tree model
    # Get syn_hw_revision, r1 or r2 etc (or just a linefeed if not a revision)
    hwrevision=$(cat /proc/sys/kernel/syno_hw_revision)

    # If syno_hw_revision is r1 or r2 it's a real Synology,
    # and I need to edit model_rN.dtb instead of model.dtb
    if [[ $hwrevision =~ r[0-9] ]]; then
        #echo "hwrevision: $hwrevision"  # debug
        hwrev="_$hwrevision"
    fi

    dtb_file="/etc.defaults/model${hwrev}.dtb"
    dtb2_file="/etc/model${hwrev}.dtb"
    #dts_file="/etc.defaults/model${hwrev}.dts"
    dts_file="/tmp/model${hwrev}.dts"
fi

adapter_cards="/usr/syno/etc.defaults/adapter_cards.conf"
adapter_cards2="/usr/syno/etc/adapter_cards.conf"
dbpath=/var/lib/disk-compatibility/
synoinfo="/etc.defaults/synoinfo.conf"

if [[ $buildnumber -gt 64570 ]]; then
    # DSM 7.2.1 and later
    #strgmgr="/var/packages/StorageManager/target/ui/storage_panel.js"
    strgmgr="/usr/local/packages/@appstore/StorageManager/ui/storage_panel.js"
elif [[ $buildnumber -ge 64561 ]]; then
    # DSM 7.2
    strgmgr="/usr/syno/synoman/webman/modules/StorageManager/storage_panel.js"
fi
vidfile="/usr/syno/etc.defaults/pci_vendor_ids.conf"
vidfile2="/usr/syno/etc/pci_vendor_ids.conf"


#------------------------------------------------------------------------------
# Restore changes from backups

if [[ $restore == "yes" ]]; then
    dbbaklist=($(find $dbpath -maxdepth 1 \( -name "*.db.new.bak" -o -name "*.db.bak" \)))
    # Sort array
    IFS=$'\n'
    dbbakfiles=($(sort <<<"${dbbaklist[*]}"))
    unset IFS

    echo ""
    if [[ ${#dbbakfiles[@]} -gt "0" ]] || [[ -f ${synoinfo}.bak ]] ||\
        [[ -f ${dtb_file}.bak ]] || [[ -f ${adapter_cards}.bak ]] ; then

        # Restore synoinfo.conf from backup
        if [[ -f ${synoinfo}.bak ]]; then
            keyvalues=("support_disk_compatibility" "support_memory_compatibility")
            keyvalues+=("mem_max_mb" "supportnvme" "support_m2_pool" "support_wdda")
            for v in "${!keyvalues[@]}"; do
                defaultval="$(/usr/syno/bin/synogetkeyvalue ${synoinfo}.bak "${keyvalues[v]}")"
                currentval="$(/usr/syno/bin/synogetkeyvalue ${synoinfo} "${keyvalues[v]}")"
                if [[ $currentval != "$defaultval" ]]; then
                    if /usr/syno/bin/synosetkeyvalue "$synoinfo" "${keyvalues[v]}" "$defaultval";
                    then
                        echo "Restored ${keyvalues[v]} = $defaultval"
                    fi
                fi
            done
        fi

        # Delete "drive_db_test_url=127.0.0.1" line (and line break) from synoinfo.conf
        sed -i "/drive_db_test_url=*/d" "$synoinfo"
        sed -i "/drive_db_test_url=*/d" /etc/synoinfo.conf

        # Restore adapter_cards.conf from backup
        # /usr/syno/etc.defaults/adapter_cards.conf
        if [[ -f ${adapter_cards}.bak ]]; then
            if cp -p "${adapter_cards}.bak" "${adapter_cards}"; then
                echo "Restored ${adapter_cards}"
            else
                restoreerr=1
                echo -e "${Error}ERROR${Off} Failed to restore ${adapter_cards}!\n"
            fi
            # /usr/syno/etc/adapter_cards.conf
            if cp -p "${adapter_cards}.bak" "${adapter_cards2}"; then
                echo -e "Restored ${adapter_cards2}"
            else
                restoreerr=1
                echo -e "${Error}ERROR${Off} Failed to restore ${adapter_cards2}!\n"
            fi

            # Make sure they don't lose E10M20-T1 network connection
            modelrplowercase=${modelname//RP/rp}
            /usr/syno/bin/set_section_key_value ${adapter_cards} E10M20-T1_sup_nic "$modelrplowercase"
            /usr/syno/bin/set_section_key_value ${adapter_cards2} E10M20-T1_sup_nic "$modelrplowercase"
        fi

        # Restore model.dtb from backup
        if [[ -f ${dtb_file}.bak ]]; then
            # /etc.default/model.dtb
            if cp -p "${dtb_file}.bak" "${dtb_file}"; then
                echo "Restored ${dtb_file}"
            else
                restoreerr=1
                echo -e "${Error}ERROR${Off} Failed to restore ${dtb_file}!\n"
            fi
            # Restore /etc/model.dtb from /etc.default/model.dtb
            if cp -p "${dtb_file}.bak" "${dtb2_file}"; then
                echo -e "Restored ${dtb2_file}"
            else
                restoreerr=1
                echo -e "${Error}ERROR${Off} Failed to restore ${dtb2_file}!\n"
            fi
        fi

        # Restore storage_panel.js from backup
        if [[ $buildnumber -gt 64570 ]]; then
            # DSM 7.2.1 and later
            strgmgrver="$(/usr/syno/bin/synopkg version StorageManager)"
        elif [[ $buildnumber -ge 64561 ]]; then
            # DSM 7.2
            strgmgrver="${buildnumber}${smallfixnumber}"
        fi
        if [[ -f "${strgmgr}.$strgmgrver" ]]; then
            if cp -p "${strgmgr}.$strgmgrver" "$strgmgr"; then
                echo "Restored $(basename -- "$strgmgr")"
            else
                restoreerr=1
                echo -e "${Error}ERROR${Off} Failed to restore $(basename -- "$strgmgr")!\n"
            fi
        else
            echo "No backup of $(basename -- "$strgmgr") found."
        fi

        echo ""
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

        # Update .db files from Synology
        /usr/syno/bin/syno_disk_db_update --update

        # Enable SynoMemCheck.service if disabled
        memcheck="/usr/lib/systemd/system/SynoMemCheck.service"
        if [[ $(/usr/syno/bin/synogetkeyvalue "$memcheck" ExecStart) == "/bin/true" ]]; then
            /usr/syno/bin/synosetkeyvalue "$memcheck" ExecStart /usr/syno/bin/syno_mem_check
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

vendor_from_id(){ 
    # Vendor ids missing in /usr/syno/etc.defaults/pci_vendor_ids.conf
    # $1 is vendor id
    # https://devicehunt.com/all-pci-vendors
    # https://pci-ids.ucw.cz/
    vendor=""
    case "${1,,}" in
        0x10ec) vendor=TEAMGROUP ;;
        0x025e) vendor=Solidigm ;;
        0x1458) vendor=Gigabyte ;;
        0x1462) vendor=MSI ;;
        0x196e) vendor=PNY ;;
        0x1987) vendor=Phison ;;
        0x1b1c) vendor=Corsair ;;
        0x1c5c) vendor="SK Hynix" ;;
        0x1cc4) vendor=UMIS ;;
        0x1cfa) vendor=Corsair ;;     # Memory only?
        0x1d97) vendor=SPCC/Lexar ;;  # 2 brands with same vid
        0x1dbe) vendor=ADATA ;;
        0x1e0f) vendor=KIOXIA ;;
        0x1e49) vendor=ZHITAI ;;
        0x1e4b) vendor=HS/MAXIO ;;    # 2 brands with same vid
        0x1f40) vendor=Netac ;;

        0x1bdc) vendor=Apacer;;
        0x0ed1) vendor=aigo ;;
        0x05dc) vendor=Lexar ;;
        0x1d79) vendor=Transcend;;
        *)
            # Get vendor from syno_hdd_vendor_ids.txt
            vidlist="$scriptpath/syno_hdd_vendor_ids.txt"
            if [[ -r "$vidlist" ]]; then
                val=$(/usr/syno/bin/synogetkeyvalue "$vidlist" "$1")
                if [[ -n "$val" ]]; then
                    vendor="$val"
                else
                    echo -e "\n${Yellow}WARNING${Off} No vendor found for vid $1" >&2
                    echo -e "You can add ${Cyan}$1${Off} and your drive's vendor to: " >&2
                    echo "$vidlist" >&2
                fi
            else
                echo -e "\n${Error}ERROR{OFF} $vidlist not found!" >&2
            fi
        ;;
    esac
}

set_vendor(){ 
    # Add missing vendors to /usr/syno/etc.defaults/pci_vendor_ids.conf
    if [[ $vendor ]]; then
        # DS1817+, DS1517+, RS1219+, RS818+ don't have pci_vendor_ids.conf
        if [[ "$vidfile" ]]; then
            if ! grep "$vid" "$vidfile" >/dev/null; then
                /usr/syno/bin/synosetkeyvalue "$vidfile" "${vid,,}" "$vendor"
                val=$(/usr/syno/bin/synogetkeyvalue "$vidfile" "${vid,,}")
                if [[ $val == "${vendor}" ]]; then
                    echo -e "\nAdded $vendor to pci_vendor_ids" >&2
                else
                    echo -e "\nFailed to add $vendor to pci_vendor_ids!" >&2
                fi
            fi
            if ! grep "$vid" "$vidfile2" >/dev/null; then
                /usr/syno/bin/synosetkeyvalue "$vidfile2" "${vid,,}" "$vendor"
            fi

            # Add leading 0 to short vid (change 0x5dc to 0x05dc)
            if [[ ${#vid} -eq "5" ]]; then
                vid="0x0${vid: -3}"
            fi
            if ! grep "$vid" "$vidfile" >/dev/null; then
                /usr/syno/bin/synosetkeyvalue "$vidfile" "${vid,,}" "$vendor"
            fi
            if ! grep "$vid" "$vidfile2" >/dev/null; then
                /usr/syno/bin/synosetkeyvalue "$vidfile2" "${vid,,}" "$vendor"
            fi

        fi
    fi
}

get_vid(){ 
    # $1 is /dev/nvme0n1 etc
    if [[ $1 ]]; then
        vid=$(nvme id-ctrl "$1" | grep -E ^vid | awk '{print $NF}')
        if [[ $vid ]]; then
            val=$(/usr/syno/bin/synogetkeyvalue "$vidfile" "${vid,,}")
            if [[ -z $val ]]; then
                vendor_from_id "$vid" && set_vendor
            fi
        fi
    fi
}

fixdrivemodel(){ 
    # Remove " 00Y" from end of Samsung/Lenovo SSDs  # Github issue #13
    if [[ $1 =~ MZ.*' 00Y' ]]; then
        hdmodel=$(printf "%s" "$1" | sed 's/ 00Y.*//')
    fi

    # Brands that return "BRAND <model>" and need "BRAND " removed.
    if [[ $1 =~ ^[A-Za-z]{3,7}' '.* ]]; then
        # See  Smartmontools database in /var/lib/smartmontools/drivedb.db
        hdmodel=${hdmodel#"WDC "}       # Remove "WDC " from start of model name
        hdmodel=${hdmodel#"HGST "}      # Remove "HGST " from start of model name
        hdmodel=${hdmodel#"TOSHIBA "}   # Remove "TOSHIBA " from start of model name

        # Old drive brands
        hdmodel=${hdmodel#"Hitachi "}   # Remove "Hitachi " from start of model name
        hdmodel=${hdmodel#"SAMSUNG "}   # Remove "SAMSUNG " from start of model name
        hdmodel=${hdmodel#"FUJISTU "}   # Remove "FUJISTU " from start of model name
    elif [[ $1 =~ ^'APPLE HDD '.* ]]; then
        # Old drive brands
        hdmodel=${hdmodel#"APPLE HDD "} # Remove "APPLE HDD " from start of model name
    fi
}

get_size_gb(){ 
    # $1 is /sys/block/sata1 or /sys/block/nvme0n1 etc
    local float
    local int
    float=$(synodisk --info /dev/"$(basename -- "$1")" | grep 'Total capacity' | awk '{print $4 * 1.0737}')
    int="${float%.*}"
    echo "$int"
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

        device=/dev/"$(basename -- "$1")"
        #fwrev=$(/usr/syno/bin/syno_hdd_util --ssd_detect | grep "$device " | awk '{print $2}')      # GitHub issue #86, 87
        # Account for SSD drives with spaces in their model name/number
        fwrev=$(/usr/syno/bin/syno_hdd_util --ssd_detect | grep "$device " | awk '{print $(NF-3)}')  # GitHub issue #86, 87

        # Get M.2 SATA SSD firmware version
        if [[ -z $fwrev ]]; then
            dev=/dev/"$(basename -- "$1")"
            fwrev=$(smartctl -a -d sat -T permissive "$dev" | grep -i firmware | awk '{print $NF}')
        fi

        # Get drive GB size
        size_gb=$(get_size_gb "$1")

        if [[ $hdmodel ]] && [[ $fwrev ]]; then
            if /usr/syno/bin/synodisk --enum -t cache | grep -q /dev/"$(basename -- "$1")"; then
                # Is SATA M.2 SSD
                nvmelist+=("${hdmodel},${fwrev},${size_gb}")
            else
                hdlist+=("${hdmodel},${fwrev},${size_gb}")
            fi
            drivelist+=("${hdmodel}")
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

    # Get drive GB size
    size_gb=$(get_size_gb "$1")

    if [[ $nvmemodel ]] && [[ $nvmefw ]]; then
        nvmelist+=("${nvmemodel},${nvmefw},${size_gb}")
        drivelist+=("${nvmemodel}")
    fi
}

getcardmodel(){ 
    # Get M.2 card model (if M.2 drives found)
    # $1 is /dev/nvme0n1 etc
    if [[ ${#nvmelist[@]} -gt "0" ]]; then
        cardmodel=$(/usr/syno/bin/synodisk --m2-card-model-get "$1")
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
    # M.2 drives in M2 adaptor card do not officially support storage pools
    if [[ -f /run/synostorage/disks/"$(basename -- "$1")"/m2_pool_support ]]; then  # GitHub issue #86, 87
        echo -n 1 > /run/synostorage/disks/"$(basename -- "$1")"/m2_pool_support
    fi
}

m2_drive(){ 
    # $1 is nvme1 etc
    # $2 is drive type (nvme or nvc)
    if [[ $m2 != "no" ]]; then
        # Check if is NVMe or SATA M.2 SSD
        if /usr/syno/bin/synodisk --enum -t cache | grep -q /dev/"$(basename -- "$1")"; then

            if [[ $2 == "nvme" ]] || [[ $2 == "nvc" ]]; then
                # Fix unknown vendor id if needed. GitHub issue #161
                # "Failed to get disk vendor" from synonvme --vendor-get
                # causes "Unsupported firmware version" warning.
                get_vid /dev/"$(basename -- "$1")"

                # Get M2 model and firmware version
                getm2info "$1" "$2"
            fi

            # Get M.2 card model if in M.2 card
            getcardmodel /dev/"$(basename -- "$1")"

            # Enable creating M.2 storage pool and volume in Storage Manager
            m2_pool_support "$1"

            rebootmsg=yes  # Show reboot message at end
        fi
    fi
}

for d in /sys/block/*; do
    # $d is /sys/block/sata1 etc
    case "$(basename -- "${d}")" in
        sd*|hd*)
            if [[ $d =~ [hs]d[a-z][a-z]?$ ]]; then
                getdriveinfo "$d"
            fi
        ;;
        sas*)
            if [[ $d =~ sas[0-9][0-9]?[0-9]?$ ]]; then
                getdriveinfo "$d"
            fi
        ;;
        sata*)
            if [[ $d =~ sata[0-9][0-9]?[0-9]?$ ]]; then
                getdriveinfo "$d"

                # In case it's a SATA M.2 SSD in device tree model NAS
                # M.2 SATA drives in M2D18 or M2S17
                m2_drive "$d"
            fi
        ;;
        nvme*)
            if [[ $d =~ nvme[0-9][0-9]?n[0-9][0-9]?$ ]]; then
                m2_drive "$d" "nvme"
            fi
        ;;
        nvc*)  # M.2 SATA drives (in PCIe M2D18 or M2S17 only?)
            if [[ $d =~ nvc[0-9][0-9]?$ ]]; then
                m2_drive "$d" "nvc"
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

# Show hdds if hdds array isn't empty
if [[ ${#hdds[@]} -eq "0" ]]; then
    echo -e "No SATA or SAS drives found\n"
else
    echo -e "\nHDD/SSD models found: ${#hdds[@]}"
    num="0"
    while [[ $num -lt "${#hdds[@]}" ]]; do
        echo "${hdds[num]} GB"
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

# Show nvmes if nvmes array isn't empty
if [[ $m2 != "no" ]]; then
    if [[ ${#nvmes[@]} -eq "0" ]]; then
        echo -e "No M.2 drives found\n"
    else    
        m2exists="yes"
        echo "M.2 drive models found: ${#nvmes[@]}"
        num="0"
        while [[ $num -lt "${#nvmes[@]}" ]]; do
            echo "${nvmes[num]} GB"
            num=$((num +1))
        done
        echo
    fi
fi


# Exit if no drives found
if [[ ${#hdds[@]} -eq "0" ]] && [[ ${#nvmes[@]} -eq "0" ]]; then
    ding
    echo -e "\n${Error}ERROR${Off} No drives found!" && exit 2
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
/usr/syno/bin/syno_disk_data_collector record

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
#db1list=($(find "$dbpath" -maxdepth 1 -regextype posix-extended\
#    -iregex ".*_host(_v7)?.db"))
#db2list=($(find "$dbpath" -maxdepth 1 -regextype posix-extended\
#    -iregex ".*_host(_v7)?.db.new"))

# Expansion Unit db files
for i in "${!eunits[@]}"; do
    #eunitdb1list+=($(find "$dbpath" -maxdepth 1 -name "${eunits[i],,}*.db"))
    eunitdb1list+=($(find "$dbpath" -maxdepth 1 -regextype posix-extended\
        -iregex ".*${eunits[i],,}(_v7)?.db"))
    #eunitdb2list+=($(find "$dbpath" -maxdepth 1 -name "${eunits[i],,}*.db.new"))
    eunitdb2list+=($(find "$dbpath" -maxdepth 1 -regextype posix-extended\
        -iregex ".*${eunits[i],,}(_v7)?.db.new"))
done

# M.2 Card db files
for i in "${!m2cards[@]}"; do
    m2carddb1list+=($(find "$dbpath" -maxdepth 1 -name "*_${m2cards[i],,}*.db"))
    m2carddb2list+=($(find "$dbpath" -maxdepth 1 -name "*_${m2cards[i],,}*.db.new"))
done


if [[ ${#db1list[@]} -eq "0" ]]; then
    ding
    echo -e "${Error}ERROR 4${Off} Host db file not found!" && exit 4
fi
# Don't check .db.new as new installs don't have a .db.new file


getdbtype(){ 
    # Detect drive db type
    # Synology misspelt compatibility as compatbility
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
        if [[ $2 == "long" ]]; then
            fname="$1"
        else
            fname=$(basename -- "${1}")
        fi
        if cp -p "$1" "$1.bak"; then
            echo -e "Backed up ${fname}" >&2
        else
            echo -e "${Error}ERROR 5${Off} Failed to backup ${fname}!" >&2
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
            echo -e "Updated ${Yellow}$hdmodel${Off} in ${Cyan}$(basename -- "$2")${Off}"
            #editcount "$2"
        else
            echo -e "\n${Error}ERROR 6b${Off} Failed to update $(basename -- "$2")${Off}"
            #exit 6
        fi

    elif [[ $1 == "empty" ]]; then  # db file only contains {}
        #if sed -i "s/{}/{\"$hdmodel\":{$fwstrng${default}}/" "$2"; then  # empty
        #if sed -i "s/{}/{\"${hdmodel//\//\\/}\":{$fwstrng${default}}/" "$2"; then  # empty
        if sed -i "s/{}/{\"${hdmodel//\//\\/}\":{$fwstrng${default}/" "$2"; then  # empty
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
    size_gb=$(printf "%s" "$1" | cut -d"," -f 3)

    #echo arg1 "$1" >&2           # debug
    #echo arg2 "$2" >&2           # debug
    #echo hdmodel "$hdmodel" >&2  # debug
    #echo fwrev "$fwrev" >&2      # debug

    # Check if db file is new or old style
    getdbtype "$2"

    if [[ $dbtype -gt "6" ]]; then
        # db type 7 used from DSM 7.1 and later
        if grep "$hdmodel"'":{"'"$fwrev" "$2" >/dev/null; then
            echo -e "${Yellow}$hdmodel${Off} already exists in ${Cyan}$(basename -- "$2")${Off}" >&2
        else
            common_string=\"size_gb\":$size_gb,
            common_string="$common_string"\"compatibility_interval\":[{
            common_string="$common_string"\"compatibility\":\"support\",
            common_string="$common_string"\"not_yet_rolling_status\":\"support\",
            common_string="$common_string"\"fw_dsm_update_status_notify\":false,
            common_string="$common_string"\"barebone_installable\":true,
            common_string="$common_string"\"barebone_installable_v2\":\"auto\",
            common_string="$common_string"\"smart_test_ignore\":false,
            common_string="$common_string"\"smart_attr_ignore\":false

            fwstrng=\"$fwrev\":{
            fwstrng="$fwstrng$common_string"
            fwstrng="$fwstrng"}]},

            default=\"default\":{
            default="$default$common_string"
            default="$default"}]}}}

            # Synology misspelt compatibility as compatbility
            if grep '"disk_compatbility_info":{}' "$2" >/dev/null; then
                # Replace "disk_compatbility_info":{} with
                # "disk_compatbility_info":{"WD40PURX-64GVNY0":{"80.00A80":{ ... }}},"default":{ ... }}}}
                #echo "Edit empty db file:"  # debug
                editdb7 "empty" "$2"

            elif grep '"'"$hdmodel"'":' "$2" >/dev/null; then
                # Replace "WD40PURX-64GVNY0":{ with "WD40PURX-64GVNY0":{"80.00A80":{ ... }}},
                #echo "Insert firmware version:"  # debug
                editdb7 "insert" "$2"

            else
                # Add "WD40PURX-64GVNY0":{"80.00A80":{ ... }}},"default":{ ... }}}
                #echo "Append drive and firmware:"  # debug
                editdb7 "append" "$2"
            fi
        fi

        # Edit existing drives in db with compatibility:unverified  # Issue #224
        if grep 'unverified' "$2" >/dev/null; then
            sed -i 's/unverified/support/g' "$2"
            if ! grep 'unverified' "$2" >/dev/null; then
                echo -e "Edited unverified drives in ${Cyan}$(basename -- "$2")${Off}" >&2
            fi
        fi

        # Edit existing drives in db with compatibility:not_support
        if [[ $incompatible == "yes" ]]; then
            if grep 'not_support' "$2" >/dev/null; then
                sed -i 's/not_support/support/g' "$2"
                if ! grep 'not_support' "$2" >/dev/null; then
                    echo -e "Edited incompatible drives in ${Cyan}$(basename -- "$2")${Off}" >&2
                fi
            fi
        fi
    elif [[ $dbtype -eq "6" ]]; then
        # db type 6 used up to DSM 7.0.1
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
            #if sed -i "s/${startstring//\//\\/}/${startstring//\//\\/}$string/" "$2"; then
            if sed -i "s/$startstring/$startstring${string//\//\\/}/" "$2"; then
                echo -e "Added ${Yellow}$hdmodel${Off} to ${Cyan}$(basename -- "$2")${Off}"
            else
                ding
                echo -e "\n${Error}ERROR 8${Off} Failed to update $(basename -- "$2")${Off}" >&2
                exit 8
            fi
        fi
    fi
}


# Fix ,, instead of , bug caused by v3.3.75
if [[ "${#db1list[@]}" -gt "0" ]]; then
    for i in "${!db1list[@]}"; do
        sed -i "s/,,/,/"  "${db1list[i]}"
    done
fi
if [[ "${#db2list[@]}" -gt "0" ]]; then
    for i in "${!db2list[@]}"; do
        sed -i "s/,,/,/"  "${db2list[i]}"
    done
fi

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
    # $1 is the file
    # $2 is the section
    # $3 is the card model and mode
    if [[ -f $1 ]] && [[ -n $2 ]] && [[ -n $3 ]]; then
        backupdb "$adapter_cards" long
        backupdb "$adapter_cards2" long

        # Check if section exists
        if ! grep '^\['"$2"'\]$' "$1" >/dev/null; then
            echo -e "Section [$2] not found in $(basename -- "$1")!" >&2
            return
        fi
        # Check if already enabled
        #
        # No idea if "cat /proc/sys/kernel/syno_hw_version" returns upper or lower case RP
        # "/usr/syno/etc.defaults/adapter_cards.conf" uses lower case rp but upper case RS
        # So we'll convert RP to rp when needed.
        #
        modelrplowercase=${modelname//RP/rp}
        val=$(/usr/syno/bin/get_section_key_value "$1" "$2" "$modelrplowercase")
        if [[ $val != "yes" ]]; then
            # /usr/syno/etc.defaults/adapter_cards.conf
            if /usr/syno/bin/set_section_key_value "$1" "$2" "$modelrplowercase" yes; then
                # /usr/syno/etc/adapter_cards.conf
                /usr/syno/bin/set_section_key_value "$adapter_cards2" "$2" "$modelrplowercase" yes
                echo -e "Enabled ${Yellow}$3${Off} for ${Cyan}$modelname${Off}" >&2
                rebootmsg=yes
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
		power_limit = "14.85,14.85";

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
		power_limit = "9.9,9.9";

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

elif [[ $1 == M2D17 ]]; then
    cat >> "$2" <<EOM2D17

	M2D17 {
		compatible = "Synology";
		model = "synology_m2d17";
		power_limit = "9.9,9.9";

		m2_card@1 {

			ahci {
				pcie_postfix = "00.0,03.0,00.0";
				ata_port = <0x00>;
			};
		};

		m2_card@2 {

			ahci {
				pcie_postfix = "00.0,03.0,00.0";
				ata_port = <0x01>;
			};
		};
	};
};
EOM2D17

fi
}

install_binfile(){ 
    # install_binfile <file> <file-url> <destination> <chmod> <bundled-path> <hash>
    # example:
    #  file_url="https://raw.githubusercontent.com/${repo}/main/bin/dtc"
    #  install_binfile dtc "$file_url" /usr/bin/dtc a+x bin/dtc

    if [[ -f "${scriptpath}/$5" ]]; then
        binfile="${scriptpath}/$5"
        echo -e "\nInstalling ${1}"
    elif [[ -f "${scriptpath}/$(basename -- "$5")" ]]; then
        binfile="${scriptpath}/$(basename -- "$5")"
        echo -e "\nInstalling ${1}"
    else
        # Download binfile
        if [[ $autoupdate == "yes" ]]; then
            reply=y
        else
            echo -e "\nNeed to download ${1}"
            echo -e "${Cyan}Do you want to download ${1}?${Off} [y/n]"
            read -r -t 30 reply
        fi
        if [[ ${reply,,} == "y" ]]; then
            echo -e "\nDownloading ${1}"
            if ! curl -kL -m 30 --connect-timeout 5 "$2" -o "/tmp/$1"; then
                echo -e "${Error}ERROR${Off} Failed to download ${1}!"
                return
            fi
            binfile="/tmp/${1}"

            printf "Downloaded md5: "
            md5sum -b "$binfile" | awk '{print $1}'

            md5=$(md5sum -b "$binfile" | awk '{print $1}')
            if [[ $md5 != "$6" ]]; then
                echo "Expected md5:   $6"
                echo -e "${Error}ERROR${Off} Downloaded $1 md5 hash does not match!"
                exit 1
            fi
        else
            echo -e "${Error}ERROR${Off} Cannot add M2 PCIe card without ${1}!"
            exit 1
        fi
    fi

    # Set binfile executable
    chmod "$4" "$binfile"

    # Copy binfile to destination
    cp -p "$binfile" "$3"
}

edit_modeldtb(){ 
    # $1 is E10M20-T1 or M2D20 or M2D18 or M2D17
    if [[ -f /etc.defaults/model.dtb ]]; then  # Is device tree model
        # Check if dtc exists and is executable
        if [[ ! -x $(which dtc) ]]; then
            md5hash="01381dabbe86e13a2f4a8017b5552918"
            branch="main"
            file_url="https://raw.githubusercontent.com/${repo}/${branch}/bin/dtc"
            # install_binfile <file> <file-url> <destination> <chmod> <bundled-path> <hash>
            install_binfile dtc "$file_url" /usr/sbin/dtc "a+x" bin/dtc "$md5hash"
        fi

        # Check again if dtc exists and is executable
        if [[ -x /usr/sbin/dtc ]]; then

            # Backup model.dtb
            backupdb "$dtb_file" long

            # Output model.dtb to model.dts
            dtc -q -I dtb -O dts -o "$dts_file" "$dtb_file"  # -q Suppress warnings
            chmod 644 "$dts_file"

            # Edit model.dts
            for c in "${cards[@]}"; do
                # Edit model.dts if needed
                if ! grep "$c" "$dtb_file" >/dev/null; then
                    dts_m2_card "$c" "$dts_file"
                    echo -e "Added ${Yellow}$c${Off} to ${Cyan}model${hwrev}.dtb${Off}" >&2
                else
                    echo -e "${Yellow}$c${Off} already exists in ${Cyan}model${hwrev}.dtb${Off}" >&2
                fi
            done

            # Compile model.dts to model.dtb
            dtc -q -I dts -O dtb -o "$dtb_file" "$dts_file"  # -q Suppress warnings

            # Set owner and permissions for model.dtb
            chmod a+r "$dtb_file"
            chown root:root "$dtb_file"
            cp -pu "$dtb_file" "$dtb2_file"  # Copy dtb file to /etc
            rebootmsg=yes
        else
            echo -e "${Error}ERROR${Off} Missing /usr/sbin/dtc or not executable!" >&2
        fi
    fi
}


for c in "${m2cards[@]}"; do
    case "$c" in
        E10M20-T1)
            echo ""
            enable_card "$adapter_cards" E10M20-T1_sup_nic "E10M20-T1 NIC"
            enable_card "$adapter_cards" E10M20-T1_sup_nvme "E10M20-T1 NVMe"
            #enable_card "$adapter_cards" E10M20-T1_sup_sata "E10M20-T1 SATA"
            cards=(E10M20-T1) && edit_modeldtb
        ;;
        M2D20)
            echo ""
            enable_card "$adapter_cards" M2D20_sup_nvme "M2D20 NVMe"
            cards=(M2D20) && edit_modeldtb
        ;;
        M2D18)
            echo ""
            enable_card "$adapter_cards" M2D18_sup_nvme "M2D18 NVMe"
            enable_card "$adapter_cards" M2D18_sup_sata "M2D18 SATA"
            cards=(M2D18) && edit_modeldtb
        ;;
        M2D17)
            echo ""
            enable_card "$adapter_cards" M2D17_sup_sata "M2D17 SATA"
            cards=(M2D17) && edit_modeldtb
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
setting="$(/usr/syno/bin/synogetkeyvalue $synoinfo $sdc)"
if [[ $force == "yes" ]]; then
    if [[ $setting == "yes" ]]; then
        # Disable support_disk_compatibility
        /usr/syno/bin/synosetkeyvalue "$synoinfo" "$sdc" "no"
        setting="$(/usr/syno/bin/synogetkeyvalue "$synoinfo" $sdc)"
        if [[ $setting == "no" ]]; then
            echo -e "\nDisabled support disk compatibility."
        fi
    elif [[ $setting == "no" ]]; then
        echo -e "\nSupport disk compatibility already disabled."
    fi
else
    if [[ $setting == "no" ]]; then
        # Enable support_disk_compatibility
        /usr/syno/bin/synosetkeyvalue "$synoinfo" "$sdc" "yes"
        setting="$(/usr/syno/bin/synogetkeyvalue "$synoinfo" $sdc)"
        if [[ $setting == "yes" ]]; then
            echo -e "\nRe-enabled support disk compatibility."
        fi
    elif [[ $setting == "yes" ]]; then
        echo -e "\nSupport disk compatibility already enabled."
    fi
fi


# Optionally disable memory compatibility warnings
smc=support_memory_compatibility
setting="$(/usr/syno/bin/synogetkeyvalue $synoinfo $smc)"
settingbak="$(/usr/syno/bin/synogetkeyvalue $synoinfo.bak $smc)"

if [[ -z $settingbak ]] || [[ -z $setting ]]; then
    # For older models that don't use "support_memory_compatibility"
    memcheck="/usr/lib/systemd/system/SynoMemCheck.service"
    memcheck_value="$(/usr/syno/bin/synosetkeyvalue "$memcheck" ExecStart)"
    if [[ $ram == "yes" ]]; then
        if [[ $memcheck_value == "/usr/syno/bin/syno_mem_check" ]]; then
            # Disable SynoMemCheck.service
            /usr/syno/bin/synosetkeyvalue "$memcheck" ExecStart /bin/true
            memcheck_value="$(/usr/syno/bin/synosetkeyvalue "$memcheck" ExecStart)"
            if [[ $memcheck_value == "/bin/true" ]]; then
                echo -e "\nDisabled SynoMemCheck memory compatibility."
            fi
        elif [[ $memcheck_value == "/bin/true" ]]; then
            echo -e "\nSynoMemCheck memory compatibility already disabled."
        fi
    else
        if [[ $memcheck_value == "/bin/true" ]]; then
            # Enable SynoMemCheck.service
            /usr/syno/bin/synosetkeyvalue "$memcheck" ExecStart /usr/syno/bin/syno_mem_check
            memcheck_value="$(/usr/syno/bin/synosetkeyvalue "$memcheck" ExecStart)"
            if [[ $memcheck_value == "/usr/syno/bin/syno_mem_check" ]]; then
                echo -e "\nRe-enabled SynoMemCheck memory compatibility."
            fi
        elif [[ $memcheck_value == "/usr/syno/bin/syno_mem_check" ]]; then
            echo -e "\nSynoMemCheck memory compatibility already enabled."
        fi
    fi
else
    # Disable "support_memory_compatibility" (not for older models)
    if [[ $ram == "yes" ]]; then
        if [[ $setting == "yes" ]]; then
            # Disable support_memory_compatibility
            /usr/syno/bin/synosetkeyvalue "$synoinfo" "$smc" "no"
            setting="$(/usr/syno/bin/synogetkeyvalue "$synoinfo" $smc)"
            if [[ $setting == "no" ]]; then
                echo -e "\nDisabled support memory compatibility."
            fi
        elif [[ $setting == "no" ]]; then
            echo -e "\nSupport memory compatibility already disabled."
        fi
    else
        if [[ $setting == "no" ]]; then
            # Enable support_memory_compatibility
            /usr/syno/bin/synosetkeyvalue "$synoinfo" "$smc" "yes"
            setting="$(/usr/syno/bin/synogetkeyvalue "$synoinfo" $smc)"
            if [[ $setting == "yes" ]]; then
                echo -e "\nRe-enabled support memory compatibility."
            fi
        elif [[ $setting == "yes" ]]; then
            echo -e "\nSupport memory compatibility already enabled."
        fi
    fi
fi

# Optionally set mem_max_mb to the amount of installed memory
if [[ $dsm -gt "6" ]]; then  # DSM 6 as has no dmidecode
    if [[ $ram == "yes" ]] && [[ -f /usr/sbin/dmidecode ]]; then
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
        setting="$(/usr/syno/bin/synogetkeyvalue $synoinfo mem_max_mb)"
        settingbak="$(/usr/syno/bin/synogetkeyvalue ${synoinfo}.bak mem_max_mb)"      # GitHub issue #107
        if [[ $ramtotal =~ ^[0-9]+$ ]]; then   # Check $ramtotal is numeric
            if [[ $ramtotal -gt "$setting" ]]; then
                /usr/syno/bin/synosetkeyvalue "$synoinfo" mem_max_mb "$ramtotal"
                # Check we changed mem_max_mb
                setting="$(/usr/syno/bin/synogetkeyvalue $synoinfo mem_max_mb)"
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
                /usr/syno/bin/synosetkeyvalue "$synoinfo" mem_max_mb "$settingbak"
                # Check we restored mem_max_mb
                setting="$(/usr/syno/bin/synogetkeyvalue $synoinfo mem_max_mb)"
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


# Enable nvme support
# shellcheck disable=SC2010  # Don't warn about "Don't use ls | grep"
if ls /dev | grep nvme >/dev/null ; then
    if [[ $m2 != "no" ]]; then
        # Check if nvme support is enabled
        setting="$(/usr/syno/bin/synogetkeyvalue $synoinfo supportnvme)"
        enabled=""
        if [[ ! $setting ]]; then
            # Add supportnvme="yes"
            /usr/syno/bin/synosetkeyvalue "$synoinfo" supportnvme "yes"
            enabled="yes"
        elif [[ $setting == "no" ]]; then
            # Change supportnvme="no" to "yes"
            /usr/syno/bin/synosetkeyvalue "$synoinfo" supportnvme "yes"
            enabled="yes"
        elif [[ $setting == "yes" ]]; then
            echo -e "\nNVMe support already enabled."
        fi

        # Check if we enabled nvme support
        setting="$(/usr/syno/bin/synogetkeyvalue $synoinfo supportnvme)"
        if [[ $enabled == "yes" ]]; then
            if [[ $setting == "yes" ]]; then
                echo -e "\nEnabled NVMe support."
            else
                echo -e "\n${Error}ERROR${Off} Failed to enable NVMe support!"
            fi
        fi
    fi
fi


# Enable m2 volume support
# shellcheck disable=SC2010  # Don't warn about "Don't use ls | grep"
if ls /dev | grep "nv[em]" >/dev/null ; then
    if [[ $m2 != "no" ]]; then
        if [[ $m2exists == "yes" ]]; then
            # Check if m2 volume support is enabled
            smp=support_m2_pool
            setting="$(/usr/syno/bin/synogetkeyvalue $synoinfo ${smp})"
            enabled=""
            if [[ ! $setting ]]; then
                # Add support_m2_pool="yes"
                #echo 'support_m2_pool="yes"' >> "$synoinfo"
                /usr/syno/bin/synosetkeyvalue "$synoinfo" "$smp" "yes"
                enabled="yes"
            elif [[ $setting == "no" ]]; then
                # Change support_m2_pool="no" to "yes"
                /usr/syno/bin/synosetkeyvalue "$synoinfo" "$smp" "yes"
                enabled="yes"
            elif [[ $setting == "yes" ]]; then
                echo -e "\nM.2 volume support already enabled."
            fi

            # Check if we enabled m2 volume support
            setting="$(/usr/syno/bin/synogetkeyvalue $synoinfo ${smp})"
            if [[ $enabled == "yes" ]]; then
                if [[ $setting == "yes" ]]; then
                    echo -e "\nEnabled M.2 volume support."
                else
                    echo -e "\n${Error}ERROR${Off} Failed to enable m2 volume support!"
                fi
            fi
        fi
    fi
fi


# Edit synoinfo.conf to prevent drive db updates
dtu=drive_db_test_url
url="$(/usr/syno/bin/synogetkeyvalue $synoinfo ${dtu})"
disabled=""
if [[ $nodbupdate == "yes" ]]; then
    if [[ ! $url ]]; then
        # Add drive_db_test_url="127.0.0.1"
        #echo 'drive_db_test_url="127.0.0.1"' >> "$synoinfo"
        /usr/syno/bin/synosetkeyvalue "$synoinfo" "$dtu" "127.0.0.1"
        disabled="yes"
    elif [[ $url != "127.0.0.1" ]]; then
        # Edit drive_db_test_url=
        /usr/syno/bin/synosetkeyvalue "$synoinfo" "$dtu" "127.0.0.1"
        disabled="yes"
    fi

    # Check if we disabled drive db auto updates
    url="$(/usr/syno/bin/synogetkeyvalue $synoinfo drive_db_test_url)"
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
        url="$(/usr/syno/bin/synogetkeyvalue $synoinfo drive_db_test_url)"
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
setting="$(/usr/syno/bin/synogetkeyvalue $synoinfo support_wdda)"
if [[ $wdda == "no" ]]; then
    if [[ $setting == "yes" ]]; then
        # Disable support_wdda
        /usr/syno/bin/synosetkeyvalue "$synoinfo" support_wdda "no"
        setting="$(/usr/syno/bin/synogetkeyvalue "$synoinfo" support_wdda)"
        if [[ $setting == "no" ]]; then
            echo -e "\nDisabled support WDDA."
        fi
    elif [[ $setting == "no" ]]; then
        echo -e "\nSupport WDDA already disabled."
    fi
fi


# Enable creating pool on drives in M.2 adaptor card
if [[ -f "$strgmgr" ]] && [[ $buildnumber -gt 42962 ]]; then
    # DSM 7.2 and later
    if [[ ${#m2cards[@]} -gt "0" ]] || [[ $forcepci == "yes" ]]; then

        if grep 'notSupportM2Pool_addOnCard' "$strgmgr" >/dev/null; then
            # Backup storage_panel.js"

            if [[ $buildnumber -gt 64570 ]]; then
                # DSM 7.2.1 and later
                strgmgrver="$(/usr/syno/bin/synopkg version StorageManager)"
            elif [[ $buildnumber -ge 64561 ]]; then
                # DSM 7.2
                strgmgrver="${buildnumber}${smallfixnumber}"
            fi

            echo ""
            if [[ ! -f "${strgmgr}.$strgmgrver" ]]; then
                if cp -p "$strgmgr" "${strgmgr}.$strgmgrver"; then
                    echo -e "Backed up $(basename -- "$strgmgr")"
                else
                    echo -e "${Error}ERROR${Off} Failed to backup $(basename -- "$strgmgr")!"
                fi
            fi

            sed -i 's/notSupportM2Pool_addOnCard:this.T("disk_info","disk_reason_m2_add_on_card"),//g' "$strgmgr"
            sed -i 's/},{isConditionInvalid:0<this.pciSlot,invalidReason:"notSupportM2Pool_addOnCard"//g' "$strgmgr"
            # Check if we edited file
            if ! grep 'notSupportM2Pool_addOnCard' "$strgmgr" >/dev/null; then
                echo -e "Enabled creating pool on drives in M.2 adaptor card."
            else
                echo -e "${Error}ERROR${Off} Failed to enable creating pool on drives in M.2 adaptor card!"
            fi
        else
            echo -e "\nCreating pool in UI on drives in M.2 adaptor card already enabled."
        fi
    fi
fi


#------------------------------------------------------------------------------
# Finished

show_changes(){  
    # $1 is drive_model,firmware_version,size_gb
    drive_model="$(printf "%s" "$1" | cut -d"," -f 1)"
    echo -e "\n$drive_model:"
    jq -r --arg drive_model "$drive_model" '.disk_compatbility_info[$drive_model]' "${db1list[0]}"
}

# Show the changes
if [[ ${showedits,,} == "yes" ]]; then
    # HDDs/SSDs
    for d in "${hdds[@]}"; do
        show_changes "$d"
    done

    # NVMe drives
    for d in "${nvmes[@]}"; do
        show_changes "$d"
    done
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
