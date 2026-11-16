#!/usr/bin/env bash
# shellcheck disable=SC2002,SC2207
#------------------------------------------------------------------------------------
# Companion script for syno_hdd_db
# Schedule companion script to run as root at shut-down
#
# https://www.synology-forum.de/threads/neue-version-7-3-2-86009.140586/post-1265124
#------------------------------------------------------------------------------------
# TODO
# Check running on DSM version that needs it
# What to do if @database is on the NVMe volume?

scriptver="v1.0.1"
script=Synology_HDD_shutdown
#repo="007revad/Synology_HDD_db"
scriptname=syno_hdd_shutdown


# Save options used for getopt
args=("$@")

if [[ $1 == "--trace" ]] || [[ $1 == "-t" ]]; then
    trace="yes"
fi

# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    echo "ERROR This script must be run as sudo or root!"
    exit 1  # Not running as sudo or root
fi

# Get NAS model
#model=$(cat /proc/sys/kernel/syno_hw_version)
model=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/synoinfo.conf upnpmodelname)
#modelname="$model"


# Show script version
#echo -e "$script $scriptver\ngithub.com/$repo\n"
echo "$script $scriptver"

# Get DSM full version
productversion=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION productversion)
buildphase=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION buildphase)
buildnumber=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION buildnumber)
smallfixnumber=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION smallfixnumber)

# Get CPU arch and platform_name
arch="$(uname -m)"
platform_name=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/synoinfo.conf platform_name)

# Show DSM full version and model
if [[ $buildphase == GM ]]; then buildphase=""; fi
if [[ $smallfixnumber -gt "0" ]]; then smallfix="-$smallfixnumber"; fi
echo "$model DSM $productversion-$buildnumber$smallfix $buildphase"

# Show CPU arch and platform_name
echo "CPU $platform_name $arch"

# Show options used
if [[ ${#args[@]} -gt "0" ]]; then
    echo -e "Using options: ${args[*]}\n"
else
    echo ""
fi

# Check Synology has synonvme
if ! which /usr/syno/bin/synonvme >/dev/null; then
    echo "${model} does not have synonvme!"
    exit 2  # NAS model does support NVMe
fi

# Check Synology has libsynonvme.so.1
if [[ ! -e /usr/lib/libsynonvme.so ]]; then
    echo "${model} does not have libsynonvme.so.1!"
    exit 2  # NAS model does support NVMe
fi

#set -x

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

# Warn if script located on M.2 drive
scriptvol=$(echo "$scriptpath" | cut -d"/" -f2)
vg=$(lvdisplay | grep /volume_"${scriptvol#volume}" | cut -d"/" -f3)
md=$(pvdisplay | grep -B 1 -E '[ ]'"$vg" | grep /dev/ | cut -d"/" -f3)
if cat /proc/mdstat | grep "$md" | grep nvme >/dev/null; then
    echo "WARNING Don't store this script on an NVMe volume!"
    exit 3  # Script is stored on NVMe volume
fi

progbar(){ 
    # $1 is pid of process
    # $2 is string to echo
    string="$2"
    local dots
    local progress
    dots=""
    while [[ -d /proc/$1 ]]; do
        dots="${dots}."
        progress="$dots"
        if [[ ${#dots} -gt "10" ]]; then
            dots=""
            progress="           "
        fi
        echo -ne "  ${2}$progress\r"; /usr/bin/sleep 0.3
    done
}

progstatus(){ 
    # $1 is return status of process
    # $2 is string to echo
    # $3 line number function was called from
    local tracestring
    local pad
    tracestring="${FUNCNAME[0]} called from ${FUNCNAME[1]} $3"
    pad=$(printf -- ' %.0s' {1..80})
    [ "$trace" == "yes" ] && printf '%.*s' 80 "${tracestring}${pad}" && echo ""
    if [[ $1 == "0" ]]; then
        echo -e "$2            "
    else
        echo -e "Line ${LINENO}: ERROR $2 failed!"
        echo "$tracestring ($scriptver)"
        if [[ $exitonerror != "no" ]]; then
            exit 1  # Skip exit if exitonerror != no
        fi
    fi
    exitonerror=""
}

package_status(){ 
    # $1 is package name
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}"
    /usr/syno/bin/synopkg status "${1}" >/dev/null
    code="$?"
    # DSM 7.2       0 = started, 17 = stopped, 255 = not_installed, 150 = broken
    # DSM 6 to 7.1  0 = started,  3 = stopped,   4 = not_installed, 150 = broken
    if [[ $code == "0" ]]; then
        #echo "$1 is started"  # debug
        return 0
    elif [[ $code == "17" ]] || [[ $code == "3" ]]; then
        #echo "$1 is stopped"  # debug
        return 1
    elif [[ $code == "255" ]] || [[ $code == "4" ]]; then
        #echo "$1 is not installed"  # debug
        return 255
    elif [[ $code == "150" ]]; then
        #echo "$1 is broken"  # debug
        return 150
    else
        return "$code"
    fi
}

package_is_running(){ 
    # $1 is package name
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}"
    /usr/syno/bin/synopkg is_onoff "${1}" >/dev/null
    code="$?"
    return "$code"
}

wait_status(){ 
    # Wait for package to finish stopping or starting
    # $1 is package
    # $2 is start or stop
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}"
    local num
    if [[ $2 == "start" ]]; then
        state="0"
    elif [[ $2 == "stop" ]]; then
        state="1"
    fi
    if [[ $state == "0" ]] || [[ $state == "1" ]]; then
        num="0"
        package_status "$1"
        while [[ $? != "$state" ]]; do
            sleep 1
            num=$((num +1))
            if [[ $num -gt "20" ]]; then
                break
            fi
            package_status "$1"
        done
    fi
}

package_stop(){ 
    # $1 is package name
    # $2 is package display name
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}"
    # Docker can take 12 minutes to stop 70 containers
    timeout 30m /usr/syno/bin/synopkg stop "$1" >/dev/null &
    pid=$!
    if [[ "$sch_task" != "yes" ]]; then
        string="Stopping ${2}"
        if [[ -t 1 ]]; then
            progbar "$pid" "$string"
        else
            echo "$string"
        fi
        wait "$pid"
        progstatus "$?" "$string" "line ${LINENO}"
    else
        echo "Stopping ${2}"
        wait "$pid"
    fi

    # Allow package processes to finish stopping
    wait_status "$1" stop &
    pid=$!
    if [[ "$sch_task" != "yes" ]]; then
        string="Waiting for ${2} to stop"
        if [[ -t 1 ]]; then
            progbar "$pid" "$string"
        else
            echo "$string"
        fi
        wait "$pid"
        progstatus "$?" "$string" "line ${LINENO}"
    else
        wait "$pid"
    fi
}

stop_packages(){ 
    # Check package is running
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}"
    if package_is_running "$pkg"; then

        # Stop package
        package_stop "$pkg" "$pkg_name"

        # Check package stopped
        if package_is_running "$pkg"; then
            #stop_pkg_fail="yes"
            echo -e "Line ${LINENO}: ERROR Failed to stop ${pkg_name}!"
#            echo "${pkg_name} status $code"
            #process_error="yes"
            return 1
        else
            #if [[ "$sch_task" == "yes" ]]; then
            if ! grep -qxF "$pkg" "$shutdown_log"; then
                echo "$pkg" >> "$shutdown_log"
            fi
        fi

        if [[ $pkg == "ContainerManager" ]] || [[ $pkg == "Docker" ]]; then
            # Stop containerd-shim
            killall containerd-shim >/dev/null 2>&1
        fi
    fi
}

skip_dev_tools(){ 
    # $1 is $package
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}"
    local skip1
    local skip2
    skip1="$(/usr/syno/bin/synogetkeyvalue "/var/packages/${package}/INFO" startable)"
    skip2="$(/usr/syno/bin/synogetkeyvalue "/var/packages/${package}/INFO" ctl_stop)"
    if [[ $skip1 == "no" ]] || [[ $skip2 == "no" ]]; then
        return 0
    else
        return 1
    fi
}

detect_scheduler(){ 
    # Sets scheduler_type to: shutdown | bootup | manual | timed | triggered | cron
    # SYNO.Core.TaskS is manually run scheduled task
    # synoschedtask is scheduled task run on a time schedule
    # SYNO.Core.Event is triggered scheduled task (boot-up, shutdown) run manually
    # esynoscheduler is triggered scheduled task (boot-up, shutdown) run at shutdown or boot-up
    local pid=$PPID comm cmdline
    scheduler_type=""
    while [[ "$pid" != "1" && -n "$pid" ]]; do
        comm=$(ps -p "$pid" -o comm=)
        cmdline=$(tr '\0' ' ' < /proc/"$pid"/cmdline 2>/dev/null)
        if [[ $comm == "esynoscheduler" && $cmdline == *"event=shutdown"* ]]; then
            scheduler_type="shutdown"; return 0
        elif [[ $comm == "esynoscheduler" && $cmdline == *"event=bootup"* ]]; then
            scheduler_type="bootup"; return 0
        else
            case "$comm" in
                SYNO.Core.TaskS)  scheduler_type="manual"; return 0 ;;
                synoschedtask)    scheduler_type="timed"; return 0 ;;
                SYNO.Core.Event)  scheduler_type="triggered"; return 0 ;;  # Manually run bootup/shutdown schedule
                crond)            scheduler_type="cron"; return 0 ;;
            esac
        fi
        pid=$(ps -p "$pid" -o ppid= | tr -d ' ')
    done
    return 1
}


# Check if script is running in an interactive shell or from schedule
if [[ -t 1 ]]; then  # Running in terminal
    echo -e "Running in an interactive shell (user terminal).\n"
else
    # Check if running via task scheduler
    if detect_scheduler; then
        sch_task="yes"
        color="no"
    fi
    echo ""
fi

shutdown_log="${scriptpath}/${scriptname}.log"

readarray -t volumes_array_sorted < <(awk '{print $2}' /proc/mounts | grep -E '^/volume[0-9]+$' | sed 's#^/##' | sort -u)

# Check there is an NVMe volume
nvme_vols=()
nvme_vols_qty=0
for vol in "${volumes_array_sorted[@]}"; do
    vg=$(lvdisplay | grep /volume_"${vol#volume}" | cut -d"/" -f3)
    md=$(pvdisplay | grep -B 1 -E '[ ]'"$vg" | grep /dev/ | cut -d"/" -f3)
    if cat /proc/mdstat | grep "$md" | grep nvme >/dev/null; then
        nvme_vols_qty=$((nvme_vols_qty +1))
        nvme_vols+=("/$vol")
    fi
done
if [[ $nvme_vols_qty -lt "1" ]]; then
    echo "No NVMe volumes found."
    exit 4  # Script not needed
fi

# Only now that we know there's something to log, replace any old log.
# If no NVMe volumes were found (e.g. NVMe not yet remounted after a
# DSM update patch is reapplied but before the follow-up reboot completes),
# we must NOT delete an existing log, since it may still hold a pending
# package list that syno_hdd_boot_test.sh hasn't consumed yet.
#if [[ "$sch_task" != "yes" ]]; then
#    # Only replace log if running from a scheduled task
#    echo -e "Not deleting shutdown.log because not running from a scheduled task.\n"
#    #exit
#elif [[ -f "$shutdown_log" ]]; then
#    rm "$shutdown_log"
#fi

[[ -f $shutdown_log ]] && read -r -a old_vols <<< "$(/usr/syno/bin/synogetkeyvalue "$shutdown_log" volumes)"
all_vols=($(printf '%s\n' "${old_vols[@]}" "${nvme_vols[@]}" | grep . | sort -u))
/usr/syno/bin/synosetkeyvalue "$shutdown_log" volumes "${all_vols[*]}"

# Get list of packages installed on NVMe volume
if ! cd /var/packages; then
    echo -e "Failed to cd to /var/packages!"
    exit 5  # Failed to cd to /var/packages
fi
declare -A package_names
declare -A package_names_rev
while IFS= read -r -d '' link && IFS= read -r -d '' target; do
    if [[ ${link##*/} == "target" ]] && echo "$target" | grep -q 'volume'; then
        # Check symlink target exists
        if [[ -a "/var/packages${link#.}" ]] ; then

            # Skip broken packages with no INFO file
            package="$(printf %s "$link" | cut -d'/' -f2 )"
            if [[ -f "/var/packages/${package}/INFO" ]]; then
                package_volume="$(printf %s "$target" | cut -d'/' -f1,2 )"

                # Check if package is on NVMe volume
                # shellcheck disable=SC2076
                if [[ "/${nvme_vols[*]}" =~ "$package_volume" ]]; then
                    package_name="$(/usr/syno/bin/synogetkeyvalue "/var/packages/${package}/INFO" displayname)"
                    if [[ -z "$package_name" ]]; then
                        package_name="$(/usr/syno/bin/synogetkeyvalue "/var/packages/${package}/INFO" package)"
                    fi

                    # Skip packages that are dev tools with no data
                    if ! skip_dev_tools "$package"; then
                        package_names["${package_name}"]="${package}"
                        package_names_rev["${package}"]="${package_name}"
                    fi
                fi
            fi
        fi
    fi
done < <(find . -maxdepth 2 -type l -printf '%p\0%l\0')

echo "Stopping packages installed on NVMe volumes: ${nvme_vols[*]}"

# Loop through package_names array and stop packages
for pkg in "${package_names[@]}"; do
    pkg_name="${package_names_rev["$pkg"]}"
    if package_is_running "$pkg"; then
        stop_packages
    else
        echo "$pkg_name is already stopped."
    fi
done

echo -e "\nFinished\n"

