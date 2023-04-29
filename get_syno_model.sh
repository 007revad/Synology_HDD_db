#!/usr/bin/env bash

Cyan='\e[0;36m'     # ${Cyan}
Off='\e[0m'         # ${Off}

echo -e "${Cyan}unamee${Off}:"
uname -a | cut -d " " -f14

echo -e "\n${Cyan}/etc/synoinfo.conf${Off} unique:"
get_key_value /etc/synoinfo.conf unique

echo -e "\n${Cyan}/etc.defaults/synoinfo.conf${Off} unique:"
get_key_value /etc.defaults/synoinfo.conf unique

echo -e "\n${Cyan}/etc/synoinfo.conf${Off} upnpmodelname:"
get_key_value /etc/synoinfo.conf upnpmodelname

echo -e "\n${Cyan}/etc.defaults/synoinfo.conf${Off} upnpmodelname:"
get_key_value /etc.defaults/synoinfo.conf upnpmodelname

echo -e "\n${Cyan}/proc/cmdline${Off} syno_hw_version:"
#cat /proc/cmdline | grep "syno_hw_version"
cat /proc/cmdline | cut -d " " -f4 | cut -d " " -f1 | cut -d "=" -f2

echo -e "\n${Cyan}/rpco/sys/kernel${Off} syno_hw_version:"
cat /proc/sys/kernel/syno_hw_version

exit

