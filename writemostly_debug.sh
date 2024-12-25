#/bin/bash

    # Get array of internal drives
    readarray -t internal_drives < <(synodisk --enum -t internal | grep 'Disk path' | cut -d"/" -f3)

        echo "internal_drives: ${internal_drives[@]}"  # debug ################
        echo "internal_drives_qty: ${#internal_drives[@]}"  # debug ###########

        # Get list of internal HDDs and qty of SSDs
        internal_ssd_qty="0"
        for idrive in "${internal_drives[@]}"; do

            echo "idrive: $idrive"  # debug ###################################

#            internal_drive="$(echo "$idrive" | awk '{printf $4}')"

#            echo "internal_drive: $internal_drive"  # debug ###################

            #if synodisk --isssd "$internal_drive" >/dev/null; then
#            if synodisk --isssd /dev/"${internal_drive:?}" >/dev/null; then
            if synodisk --isssd /dev/"${idrive:?}" >/dev/null; then
                # exit code 0 = is not SSD
                # exit code 1 = is SSD

                # Add internal HDDs to array
                internal_hdds+=("$idrive")
            else
                # Count number of internal 2.5 inch SSDs
                internal_ssd_qty=$((internal_ssd_qty +1))
            fi
        done

        echo "internal_ssd_qty: $internal_ssd_qty"  # debug ###################
        echo "internal_hdd_qty: ${#internal_hdds[@]}"  # debug ################
        echo "internal_hdds: ${internal_hdds[@]}"  # debug ####################

        # Set HDDs to writemostly if there's also internal SSDs
        if [[ $internal_ssd_qty -gt "0" ]] && [[ ${#internal_hdds[@]} -gt "0" ]]; then
            # There are internal SSDs and HDDs
            echo -e "\nSetting internal HDDs state to write_mostly:"
            for idrive in "${internal_hdds[@]}"; do

                echo "set_writemostly writemostly $idrive"  # debug ###########

            done
        fi

