#!/bin/bash
# Fix Unrecognized firmware version

# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    echo "This script must be run as sudo or root!"
    exit 1
fi

file="/usr/syno/synoman/synoSDSjslib/dist/extjs-patch.bundle.js"
#file="/volume1/test/extjs/extjs-patch.bundle.js"  # debug #####################

# Restore extjs-patch.bundle.js from backup
if [[ ${1,,} == "--restore" ]]; then
    if [[ -f "${file}.bak" ]]; then
        cp -p "${file}.bak" "$file"
        echo "Restored" && exit
    else
        echo "Backup not found!" && exit
    fi
fi

# Backup extjs-patch.bundle.js
cp -p "$file" "${file}.bak"

# Edit extjs-patch.bundle.js
sed -i 's|:"upgrade_database"===e&&(a="sm-fwupgrade-upgrade-db-link",r="orange-status",o=_T("disk_info","fwupgrade_status_upgrade_database"))||g' "$file"

echo "Finished"

