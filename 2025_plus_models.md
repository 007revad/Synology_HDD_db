## 2025 series or later Plus models

### Unverified 3rd party drive limitations and unoffical solutions

| Action | Works | Result | Solution |
|--------|--------------|--------|----------|
| Setup the NAS with Synology drives | yes |  |  |
| Setup the NAS with 3rd party SSDs | yes | Lots of warnings | Use [Synology HDD db](https://github.com/007revad/Synology_HDD_db) |
| Setup the NAS with unverified 3rd party HDDs | **No!** |  | See <a href="#setting-up-a-new-2025-or-later-plus-model-with-only-unverified-hdds">Setup with unverifed HDDs</a> |
| Migrate unverified 3rd party drives from other Synology | yes | Lots of warnings | Use [Synology HDD db](https://github.com/007revad/Synology_HDD_db) |
| Replace migrated 3rd party drives with 3rd party drives | **No!** |  | Use [Synology HDD db](https://github.com/007revad/Synology_HDD_db) |
| Expand migrated 3rd party storage pool with 3rd party drives | **No!** |  | Use [Synology HDD db](https://github.com/007revad/Synology_HDD_db) |
| Use 3rd party drive as hot spare | **No!** |  | Use [Synology HDD db](https://github.com/007revad/Synology_HDD_db) |
| Create a cache with 3rd party SSDs | **No!** |  | Use [Synology HDD db](https://github.com/007revad/Synology_HDD_db) |
| Delete and create storage pool on migrated 3rd party drives | **No!** |  | See <a href="#deleting-and-recreating-your-storage-pool-on-unverified-hdds">Recreating storage pool</a> |

<br>

### Setting up a new 2025 or later plus model with only unverified HDDs

Credit to Alex_of_Chaos on reddit

DSM won't install on a 2025 or later series plus model if you only have unverified HDDs. But we can get around that.

1. Start telnet by entering `http://<NAS-IP>:5000/webman/start_telnet.cgi` into your browser's address bar.
   - Replace `<NAS-IP>` with the IP address of the Synology NAS. 
3. Open a telnet client on your computer and log in to telnet with:
    - `root` for the username
    - `101-0101` for the password
5. Execute the following command: (using a while loop in case DSM is running in a VM)
    ```
    while true; do touch /tmp/installable_check_pass; sleep 1; done
    ```
7. Refresh the web installation page and install DSM.
8. Then in the telnet window, or via SSH, execute the following command:
   ```
   /usr/syno/bin/synosetkeyvalue support_disk_compatibility no
   ```
9.  If Storage Manager is already open close then open it, or refresh the web page.
10. You can now create your storage pool from Storage Manager.

<br>

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

8. If Storage Manager is already open close then open it, or refresh the web page.
9. You can now create your storage pool from Storage Manager.

#### Via a scheduled task

First setup email notifications (if you haven't already):

1. Go to **Control Panel** > **Notification** > **Email** > click **Setup**.

Then create the scheduled task:

1. Go to **Control Panel** > **Task Scheduler** > click **Create** > **Scheduled Task** > **User-defined script**.
2. Enter a task name.
3. Select **root** as the user (The script needs to run as root).
4. Untick **Enable**.
5. Click **Task Settings**.
6. Tick **Send run details by email** and enter your email address.
7. In the box under **User-defined script** paste the following: 
    ```
    mkdir -m775 /opt
    cd /opt || (echo "Failed to CD to /opt"; exit 1)
    curl -O "https://raw.githubusercontent.com/007revad/Synology_HDD_db/refs/heads/main/syno_hdd_db.sh"
    curl -O "https://raw.githubusercontent.com/007revad/Synology_HDD_db/refs/heads/main/syno_hdd_vendor_ids.txt"
    chmod 750 /opt/syno_hdd_db.sh
    /opt/syno_hdd_db.sh -e
    ```
8. Click **OK** > **OK** > type your password > **Submit** to save the scheduled task.
9. Now select the scheduld task and click **Run** > **OK**.
10. Check your emails to make sure the scheduled task ran without any error.
11. If Storage Manager is already open close then open it, or refresh the web page.
12. You can now create your storage pool from Storage Manager.

