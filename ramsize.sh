#!/usr/bin/env bash

#IFS=$'\n' read -r -d '' -a array < <(dmidecode -t memory | grep "[Ss]ize")
#for f in "${!array[@]}"; do echo "'${array[f]}'";  r=$(printf %s "${array[num]}" | awk '{print $2}'); echo "'$r'"; done

IFS=$'\n' read -r -d '' -a array < <(dmidecode -t memory | grep "[Ss]ize")
if [[ ${#array[@]} -gt "0" ]]; then
    for f in "${!array[@]}"; do
        echo "'${array[f]}'"
        ramsize=$(printf %s "${array[num]}" | awk '{print $2}')
        echo "'$ramsize'"
    done
fi

exit

