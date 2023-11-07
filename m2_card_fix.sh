#!/usr/bin/env bash

# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    echo "This script must be run as sudo or root!"
fi

# Set fans to cool mode if PCIe card installed
synosetkeyvalue /etc.defaults/synoinfo.conf support_fan_adjust_by_ext_nic "cool"
synosetkeyvalue /etc/synoinfo.conf support_fan_adjust_by_ext_nic "cool"


url="https://raw.githubusercontent.com/007revad/Synology_HDD_db/develop/"


model=$(cat /proc/sys/kernel/syno_hw_version)
modelname="$model"

#if [[ $modelname == "DS1821+" ]] || [[ $modelname == "DS1823xs+" ]];
if [[ $modelname == "DS1821+" ]] || [[ $modelname == "DS1621+" ]] ||\
    [[ $modelname == "DS1520+" ]] || [[ $modelname == "RS822rp+" ]] ||\
    [[ $modelname == "RS822+" ]] || [[ $modelname == "RS1221rp+" ]] ||\
    [[ $modelname == "RS1221+" ]];
then
    echo "$modelname"
else
    echo "$modelname not supported"
    exit
fi


buildnumber="64570"
currentbldnum=$(synogetkeyvalue /etc.defaults/VERSION buildnumber)

if [[ $buildnumber != "$currentbldnum" ]]; then
    echo "$currentbldnum not supported"
    exit
fi


# Backup /usr/lib/libsynonvme.so.1
if ! cp -p "/usr/lib/libsynonvme.so.1" "/usr/lib/libsynonvme.so.1.bak.72-u3"; then
    echo "Failed to backup libsynonvme.so.1"
fi

# Download libsynonvme.so.1
echo -e "\nDownloading 64570_libsynonvme.so.1"
if curl -kL "${url}lib/${buildnumber}_libsynonvme.so.1" -o "/tmp/libsynonvme.so.1"; then
    # Check we didn't download a 404 web page
    downloaded=$(wc -c "/tmp/libsynonvme.so.1" | awk '{print $1}')
    if [[ $downloaded == "54154" ]]; then
        # Set permission on downloaded libsynonvme.so.1
        if chmod 644 "/tmp/libsynonvme.so.1"; then
            # Replace libsynonvme.so.1
            if ! cp -p "/tmp/libsynonvme.so.1" "/usr/lib/libsynonvme.so.1"; then
                echo "Failed to copy libsynonvme.so.1"
            fi
        else
            echo "Failed to set permissions on libsynonvme.so.1"
        fi
    else
        echo "Failed to download libsynonvme.so.1"
    fi
else
    echo "Failed to download libsynonvme.so.1"
fi

# Delete tmp file
if ! rm "/tmp/libsynonvme.so.1"; then
    echo "Failed to delete /tmp/libsynonvme.so.1"
fi


# Backup /usr/syno/bin/synonvme
if ! cp -p "/usr/syno/bin/synonvme" "/usr/syno/bin/synonvme.bak.72-u3"; then
    echo "Failed to backup synonvme"
fi

# Download synonvme
echo -e "\nDownloading 64570_synonvme"
if curl -kL "${url}bin/${buildnumber}_synonvme" -o "/tmp/synonvme"; then
    # Check we didn't download a 404 web page
    downloaded=$(wc -c "/tmp/synonvme" | awk '{print $1}')
    if [[ $downloaded == "17241" ]]; then
        # Set permission on downloaded synonvme
        if chmod 755 "/tmp/synonvme"; then
            # Replace synonvme
            if ! cp -p "/tmp/synonvme" "/usr/syno/bin/synonvme"; then
                echo "Failed to copy synonvme"
            fi
        else
            echo "Failed to set permissions on synonvme"
        fi
    else
        echo "Failed to download synonvme"
    fi
else
    echo "Failed to download synonvme"
fi

# Delete tmp file
if ! rm "/tmp/synonvme"; then
    echo "Failed to delete /tmp/synonvme"
fi

