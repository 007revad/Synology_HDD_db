#!/usr/bin/env bash
# shellcheck disable=SC2002,2207
#------------------------------------------------------------------------------------
# Companion script for syno_hdd_db
# Schedule companion script to run as root at shut-down
#
# https://www.synology-forum.de/threads/neue-version-7-3-2-86009.140586/post-1265124
#------------------------------------------------------------------------------------
# TODO
# Check running on DSM version that needs it
# What to do if @database is on the NVMe volume?

scriptver="v1.0.0"
script=Synology_HDD_shutdown
#repo="007revad/Synology_HDD_db"
scriptname=syno_hdd_shutdown

ding(){ 
    printf \\a
}

# Save options used for getopt
args=("$@")

if [[ $1 == "--trace" ]] || [[ $1 == "-t" ]]; then
    trace="yes"
fi

# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    ding
    echo -e "ERROR This script must be run as sudo or root!"
    exit 1  # Not running as sudo or root
fi

# Get NAS model
model=$(cat /proc/sys/kernel/syno_hw_version)
#modelname="$model"


# Show script version
#echo -e "$script $scriptver\ngithub.com/$repo\n"
echo "$script $scriptver"

# Get DSM full version
productversion=$(synogetkeyvalue /etc.defaults/VERSION productversion)
buildphase=$(synogetkeyvalue /etc.defaults/VERSION buildphase)
buildnumber=$(synogetkeyvalue /etc.defaults/VERSION buildnumber)
smallfixnumber=$(synogetkeyvalue /etc.defaults/VERSION smallfixnumber)

# Get CPU arch and platform_name
arch="$(uname -m)"
platform_name=$(synogetkeyvalue /etc.defaults/synoinfo.conf platform_name)

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
if ! which synonvme >/dev/null; then
    ding
    echo "${model} does not have synonvme!"
    exit 2  # NAS model does support NVMe
fi

# Check Synology has libsynonvme.so.1
if [[ ! -e /usr/lib/libsynonvme.so ]]; then
    ding
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
    ding
    echo -e "WARNING Don't store this script on an NVMe volume!"
    exit 3  # Script is stored on NVMe volume
fi

shutdown_log="${scriptpath}/${scriptname}.log"
# Delete old shutdown_log
if [[ -f "$shutdown_log" ]]; then
    rm "$shutdown_log"
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
        ding
        echo -e "Line ${LINENO}: ERROR $2 failed!"
        echo "$tracestring ($scriptver)"
        if [[ $exitonerror != "no" ]]; then
            exit 1  # Skip exit if exitonerror != no
        fi
    fi
    exitonerror=""
    #echo "return: $1"  # debug
}

package_status(){ 
    # $1 is package name
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}"
#    local code
    synopkg status "${1}" >/dev/null
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
    synopkg is_onoff "${1}" >/dev/null
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
    timeout 30m synopkg stop "$1" >/dev/null &
    pid=$!
    string="Stopping ${2}"
    progbar "$pid" "$string"
    wait "$pid"
    progstatus "$?" "$string" "line ${LINENO}"

    # Allow package processes to finish stopping
    wait_status "$1" stop &
    pid=$!
    string="Waiting for ${2} to stop"
    progbar "$pid" "$string"
    wait "$pid"
    progstatus "$?" "$string" "line ${LINENO}"
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
            ding
            echo -e "Line ${LINENO}: ERROR Failed to stop ${pkg_name}!"
#            echo "${pkg_name} status $code"
            #process_error="yes"
            return 1
        else
            echo "$pkg" >> "$shutdown_log"
            #stop_pkg_fail=""
        fi

        if [[ $pkg == "ContainerManager" ]] || [[ $pkg == "Docker" ]]; then
            # Stop containerd-shim
            killall containerd-shim >/dev/null 2>&1
        fi
#    else
#        skip_start="yes"
    fi
}

skip_dev_tools(){ 
    # $1 is $package
    [ "$trace" == "yes" ] && echo "${FUNCNAME[0]} called from ${FUNCNAME[1]}"
    local skip1
    local skip2
    skip1="$(synogetkeyvalue "/var/packages/${package}/INFO" startable)"
    skip2="$(synogetkeyvalue "/var/packages/${package}/INFO" ctl_stop)"
    if [[ $skip1 == "no" ]] || [[ $skip2 == "no" ]]; then
        return 0
    else
        return 1
    fi
}


# Get list of volumes with shared folders
readarray -t shares_array < <(synoshare --enum | tail -n +5)
for share in "${shares_array[@]}"; do

#echo "share: $share"  # debug ################################################

    if [[ $buildnumber -gt "64570" ]]; then
        # DSM 7.2.1 and later
        # synoshare --get-real-path is case insensitive
        path="$(synoshare --get-real-path "$share" | cut -d"/" -f2)"
    else
        # DSM 7.2 and earlier
        # synoshare --getmap is case insensitive
        path="$(synoshare --getmap web_packages | grep volume | cut -d"[" -f2 | cut -d"]" -f1)"
        # I could also have used:
        # web_pkg_path=$(/usr/syno/sbin/synoshare --get web_packages | tr '[]' '\n' | sed -n "9p")
    fi

    # Ignore external USB and eSATA volumes
    if echo "$path" | grep -q -E 'volume[0-9]'; then
        volumes_array+=("$path")
    fi
done

#echo -e "\nvolumes_array:"                          # debug ##################
#for v in "${volumes_array[@]}"; do echo "$v"; done  # debug ##################
#echo -e "\n"                                        # debug ##################

# Sort array to remove duplicates
IFS=$'\n'
volumes_array_sorted=($(sort -u <<<"${volumes_array[*]}"))
unset IFS

#echo -e "\nvolumes_array_sorted:"                          # debug ###########
#for v in "${volumes_array_sorted[@]}"; do echo "$v"; done  # debug ###########
#echo -e "\n"                                               # debug ###########

#exit

# Check there is an NVMe volume
nvme_vols=()
for vol in "${volumes_array_sorted[@]}"; do

#echo "$vol"  # debug #########################################################

    vg=$(lvdisplay | grep /volume_"${vol#volume}" | cut -d"/" -f3)
    md=$(pvdisplay | grep -B 1 -E '[ ]'"$vg" | grep /dev/ | cut -d"/" -f3)
    if cat /proc/mdstat | grep "$md" | grep nvme >/dev/null; then
        nvme_vols_qty=$((nvme_vols_qty +1))
        nvme_vols+=("$vol")
    fi
done
if [[ $nvme_vols_qty -lt "0" ]]; then
    ding
    echo -e "No NVMe volumes found."
    exit 4  # Script not needed
fi


#echo "nvme_vols_qty $nvme_vols_qty"             # debug ######################
#for v in "${nvme_vols[@]}"; do echo "$v"; done  # debug ######################
#echo ""                                         # debug ######################

#exit


# Get list of packages installed on NVMe volume
if ! cd /var/packages; then
    ding
    echo -e "Failed to cd to /var/packages!"
    exit 5  # Failed to cd to /var/packages
fi
declare -A package_names
declare -A package_names_rev
#package_infos=( )
while IFS= read -r -d '' link && IFS= read -r -d '' target; do
    if [[ ${link##*/} == "target" ]] && echo "$target" | grep -q 'volume'; then
        # Check symlink target exists
        if [[ -a "/var/packages${link#.}" ]] ; then

            # Skip broken packages with no INFO file
            package="$(printf %s "$link" | cut -d'/' -f2 )"
            if [[ -f "/var/packages/${package}/INFO" ]]; then
                package_volume="$(printf %s "$target" | cut -d'/' -f1,2 )"

#echo "package_volume: $package_volume"  # debug ###############################

                # Check if package is on NVMe volume
                # shellcheck disable=SC2076
                if [[ "/${nvme_vols[*]}" =~ "$package_volume" ]]; then
                    package_name="$(synogetkeyvalue "/var/packages/${package}/INFO" displayname)"
                    if [[ -z "$package_name" ]]; then
                        package_name="$(synogetkeyvalue "/var/packages/${package}/INFO" package)"
                    fi

#echo "package_name: $package_name"  # debug ###############################

                    # Skip packages that are dev tools with no data
                    if ! skip_dev_tools "$package"; then
                        #package_infos+=("${package_volume}|${package_name}")
                        package_names["${package_name}"]="${package}"
                        package_names_rev["${package}"]="${package_name}"
                    fi
                fi
            fi
        fi
    fi
done < <(find . -maxdepth 2 -type l -printf '%p\0%l\0')

#echo -e "\npackage_infos:"
#for p in "${package_infos[@]}"; do echo "$p"; done

#echo -e "\npackage_names:"
#for p in "${package_names[@]}"; do echo "$p"; done

#echo -e "\npackage_names_rev:"
#for p in "${package_names_rev[@]}"; do echo "$p"; done


# Loop through pkgs_sorted array and process package
for pkg in "${package_names[@]}"; do
    pkg_name="${package_names_rev["$pkg"]}"
    #process_error=""
    stop_packages

#echo "stop_package: $pkg"  # debug ############################################

done



