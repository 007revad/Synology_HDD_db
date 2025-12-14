#!/usr/bin/env bash
# shellcheck disable=SC2317

Yellow='\e[0;33m'   # ${Yellow}
Off='\e[0m'         # ${Off}

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


ding(){ 
    printf \\a
}


# Warn if script located on M.2 drive
get_script_vol() {
    local script_root vol_num vg_name
    script_root="${scriptpath#/*}"
    script_root="${script_root%%/*}"
    if [[ $script_root =~ ^volume ]]
    then
        vol_num="${script_root:6}"
        vg_name=$(lvs --noheadings --select=lv_name="volume_$vol_num" --options=vg_name)
        vg_name="${vg_name// }"
        #vol_name=$(pvs --noheadings --select=vg_name="$vg_name" --options=pv_name)
        #vol_name="${vol_name// }"
        # Only get first partition on volume group
        vol_name=$(pvs --noheadings --select=vg_name="$vg_name" --options=pv_name | awk '{print $1}')
    else
        vol_name=$(df --output=source "/$script_root" |sed 1d)
    fi
}

#set -x  # debug #####################################################################

get_script_vol # sets $vol_name to /dev/whatever
if grep -qE "^${vol_name#/dev/} .+ nvme" /proc/mdstat
then
    ding
    echo -e "\n${Yellow}WARNING${Off} Don't store this script on an NVMe volume!"
    exit 3
fi

echo -e "\n$scriptfile is not on an NVMe volume"

exit


