#!/usr/bin/env bash

for d in $(cat /proc/partitions | awk '{print $4}'); do
    if [ ! -e /dev/"$d" ]; then
        continue;
    fi
    #echo $d  # debug
    case "$d" in
        sd*|hd*)
            if [[ $d =~ [hs]d[a-z]$ ]]; then
                echo -e "\n$d"  # debug
                hdmodel=$(smartctl -i "/dev/$d" | grep -i "Device Model:" | awk '{print $3 $4 $5}')
                if [[ ! $hdmodel ]]; then
                    hdmodel=$(smartctl -i "/dev/$d" | grep -i "Product:" | awk '{print $2 $3 $4}')
                fi
                echo "Model:    '$hdmodel'"  # debug

                fwrev=$(smartctl -i "/dev/$d" | grep -i "Firmware Version:" | awk '{print $3}')
                if [[ ! $fwrev ]]; then
                    fwrev=$(smartctl -i "/dev/$d" | grep -i "Revision:" | awk '{print $2}')
                fi
                echo "Firmware: '$fwrev'"  # debug
            fi
        ;;
        sata*|sas*)
            if [[ $d =~ (sas|sata)[0-9][0-9]?[0-9]?$ ]]; then
                echo -e "\n$d"  # debug
                hdmodel=$(smartctl -i "/dev/$d" | grep -i "Device Model:" | awk '{print $3 $4 $5}')
                if [[ ! $hdmodel ]]; then
                    hdmodel=$(smartctl -i "/dev/$d" | grep -i "Product:" | awk '{print $2 $3 $4}')
                fi
                echo "Model:    '$hdmodel'"  # debug

                fwrev=$(smartctl -i "/dev/$d" | grep -i "Firmware Version:" | awk '{print $3}')
                if [[ ! $fwrev ]]; then
                    fwrev=$(smartctl -i "/dev/$d" | grep -i "Revision:" | awk '{print $2}')
                fi
                echo "Firmware: '$fwrev'"  # debug
            fi
        ;;
        nvme*)
            if [[ $d =~ nvme[0-9][0-9]?n[0-9][0-9]?$ ]]; then
                echo -e "\n$d"  # debug
                n=n$(printf "%s" "$d" | cut -d "n" -f 2)
                nvmemodel=$(cat "/sys/class/nvme/$n/model")
                echo "NVMe Model:    '$nvmemodel'"  # debug

                nvmemodel=$(echo "$nvmemodel" | xargs)  # trim leading and trailing white space
                echo "NVMe Model:    '$nvmemodel'"  # debug

                nvmefw=$(cat "/sys/class/nvme/$n/firmware_rev")
                echo "NVMe Firmware: '$nvmefw'"  # debug

                nvmefw=$(echo "$nvmefw" | xargs)  # trim leading and trailing white space
                echo "NVMe Firmware: '$nvmefw'"  # debug
            fi
        ;;
    esac
done


exit

