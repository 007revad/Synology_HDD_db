#!/usr/bin/env bash
# Issue 213

dsm=7
ram=yes
Error=
Off=
synoinfo="/etc/synoinfo.conf"

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
        setting="$(/usr/syno/bin/synogetkeyvalue "$synoinfo" mem_max_mb)"
        settingbak="$(/usr/syno/bin/synogetkeyvalue "${synoinfo}".bak mem_max_mb)"    # GitHub issue #107

echo "ramtotal:    $ramtotal"
echo "setting:     $setting"
echo "settingbak:  $settingbak"

        if [[ $ramtotal =~ ^[0-9]+$ ]]; then   # Check $ramtotal is numeric
            if [[ $ramtotal -gt "$setting" ]]; then

echo "ramtotal -gt setting"

            elif [[ $setting -gt "$ramtotal" ]] && [[ $setting -gt "$settingbak" ]];  # GitHub issue #107 
            then

echo "setting -gt ramtotal and setting -gt settingbak"

            elif [[ $ramtotal == "$setting" ]]; then

echo "ramtotal == setting"

            else [[ $ramtotal -lt "$setting" ]]

echo "ramtotal -lt setting"

            fi

        else
            echo -e "\n${Error}ERROR${Off} Total memory size is not numeric: '$ramtotal'"
        fi
    fi
fi

