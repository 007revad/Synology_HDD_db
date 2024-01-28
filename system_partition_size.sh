#/bin/bash

echo -e "\nCheck the 'Size, Used, Avail and Use%'\n"
echo "--------------------------------------------------------"
echo "Filesystem              Size  Used Avail Use% Mounted on"
echo "--------------------------------------------------------"
df -h | grep '/dev/md0'

echo -e "\n\nCheck which folder is using all the space:"
for volume in /volume*; do
    set -- "$@" "--exclude=${volume:1}"
done
echo -e "\n-------------------------"
echo "Size    Folder"
echo "-------------------------"
du -hd 1 "$@" 2>/dev/null
echo -e "\nThe last line is the total space used."
echo "It is normal for /usr to be around 1GB."
echo "/root should be no more than a few MB."

