## 2025 series DS Plus models

### Deleting and recreating your storage pool on unverified HDDs

You can't download Synology HDD db to a volume because you've just deleted your storage pool. So you'd first need to download Synology HDD db to a system folder and run it from there.

You can do this via SSH or via a scheduled task.

#### Via SSH

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

6. Finally run syno_hdd_db. You don't need any options at this point.
    ```
    sudo -s /opt/syno_hdd_db.sh
    ```

8. You can now create your storage pool from Storage Manager

#### Via a scheduled task

1. Go to **Control Panel** > **Task Scheduler** > click **Create** > **Scheduled Task** > **User-defined script**.
2. Enter a task name.
3. Select **root** as the user (The script needs to run as root).
4. Untick **Enable**.
5. Click **Task Settings**.
6. In the box under **User-defined script** paste the following: 
    ```
    mkdir -m775 /opt
    cd /opt || (echo "Failed to CD to /opt"; exit 1)
    curl -O "https://raw.githubusercontent.com/007revad/Synology_HDD_db/refs/heads/main/syno_hdd_db.sh"
    curl -O "https://raw.githubusercontent.com/007revad/Synology_HDD_db/refs/heads/main/syno_hdd_vendor_ids.txt"
    chmod 750 /opt/syno_hdd_db.sh
    /opt/syno_hdd_db.sh
    ```
7. Click **OK** to save the settings.

You can now create your storage pool from Storage Manager

