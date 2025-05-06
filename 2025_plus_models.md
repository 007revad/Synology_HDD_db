## 2025 series DS Plus models

### Deleting and recreating your storage pool on unverified HDDs

You can't download Synology HDD db to a volume because you've just deleted your storage pool. So you'd first need to download Synology HDD db to a system folder and run it from there.

1. Create and cd to /opt
    ```
    sudo mkdir /opt && sudo chmod 775 /opt
    ```

2. Create /opt
    ```
    sudo mkdir -m775 /opt
    ```

2. cd to /opt
    ```
    cd /opt || (echo "Failed to CD to /opt"; exit 1)
    ```

3. Download syno_hdd_db.sh to /opt
    ```
    sudo curl -O "https://raw.githubusercontent.com/007revad/Synology_HDD_db/refs/heads/main/syno_hdd_db.sh"
    ```

4. Download syno_hdd_vendor_ids.txt to /opt
    ```
    sudo curl -O "https://raw.githubusercontent.com/007revad/Synology_HDD_db/refs/heads/main/syno_hdd_vendor_ids.txt"
    ```

5. Then set permissions on /opt/syno_hdd_db.sh
    ```
    sudo chmod 750 /opt/syno_hdd_db.sh
    ```

6. Finally run
    ```sudo -s /opt/syno_hdd_db.sh```

7. You can now create your storage pool from Storage Manager

