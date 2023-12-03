# Synology HDD db

<a href="https://github.com/007revad/Synology_HDD_db/releases"><img src="https://img.shields.io/github/release/007revad/Synology_HDD_db.svg"></a>
<a href="https://hits.seeyoufarm.com"><img src="https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2F007revad%2FSynology_HDD_db&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=views&edge_flat=false"/></a>
[![](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/007revad)
[![committers.top badge](https://user-badge.committers.top/australia/007revad.svg)](https://user-badge.committers.top/australia/007revad)
<!-- [![committers.top badge](https://user-badge.committers.top/australia_public/007revad.svg)](https://user-badge.committers.top/australia_public/007revad) -->
<!-- [![committers.top badge](https://user-badge.committers.top/australia_private/007revad.svg)](https://user-badge.committers.top/australia_private/007revad) -->
<!-- [![Github Releases](https://img.shields.io/github/downloads/007revad/synology_hdd_db/total.svg)](https://github.com/007revad/Synology_HDD_db/releases) -->

### Description

Add your SATA or SAS HDDs and SSDs plus SATA and NVMe M.2 drives to your Synology's compatible drive databases, including your Synology M.2 PCIe card and Expansion Unit databases. 

The script works in DSM 7, including DSM 7.2, and DSM 6.

It also has a restore option to undo all the changes made by the script.

#### What the script does:

* Gets the Synology NAS model and DSM version (so it knows which db files to edit).
* Gets a list of the HDD, SSD, SAS and NVMe drives installed in your Synology NAS.
* Gets each drive's model number and firmware version.
* Backs up the database files if there is no backup already.
* Checks if each drive is already in the Synology's compatible-drive database.
* Adds any missing drives to the Synology's compatible-drive database.
* Prevents DSM auto updating the drive database.
* Optionally disable DSM's "support_disk_compatibility".
* Optionally disable DSM's "support_memory_compatibility" to prevent <a href=images/ram_warning.png/>non-Synology memory notifications</a>.
* Optionally edits max supported memory to match the amount of memory installed, if installed memory is greater than the current max memory setting.
* Enables M2D20, M2D18, M2D17 and E10M20-T1 if present on Synology NAS that don't officially support them.
* Checks that M.2 volume support is enabled (on models that have M.2 slots or PCIe slots).
* Enables creating M.2 storage pools and volumes from within Storage Manager **(newer models only?)**.
* Makes DSM recheck disk compatibility so rebooting is not needed if you don't have M.2 drives (DSM 7 only).
    * **If you have M.2 drives you may need to reboot.**
    * Reminds you that you may need to reboot the Synology after running the script.
* Checks if there is a newer version of this script and offers to download it for you.
  * The new version available messages time out so they don't prevent the script running if it is scheduled to run unattended.

### Download the script

See <a href=images/how_to_download.png/>How to download the script</a> for the easiest way to download the script.

Do ***NOT*** save the script to a M.2 volume. The M.2 volume won't be available until after the script has run.

### When to run the script

You would need to re-run the script after a DSM update. If you have DSM set to auto update the best option is to run the script every time the Synology boots, and the best way to do that is to <a href=how_to_schedule.md/>setup a scheduled task</a> to run the the script at boot-up.

**Note:** After you first run the script you may need to reboot the Synology to see the effect of the changes.

### Options when running the script <a name="options"></a>

There are optional flags you can use when running the script:
```YAML
  -s, --showedits       Show edits made to <model>_host db and db.new file(s)
  -n, --noupdate        Prevent DSM updating the compatible drive databases
  -m, --m2              Don't process M.2 drives
  -f, --force           Force DSM to not check drive compatibility
  -r, --ram             Disable memory compatibility checking (DSM 7.x only),
                        and sets max memory to the amount of installed memory
  -w, --wdda            Disable WD WDDA
  -e, --email           Disable colored text in output scheduler emails.
      --restore         Undo all changes made by the script
      --autoupdate=AGE  Auto update script (useful when script is scheduled)
                          AGE is how many days old a release must be before
                          auto-updating. AGE must be a number: 0 or greater
  -h, --help            Show this help message
  -v, --version         Show the script version
```

**Note:** If you have some Synology drives and want to update their firmware run the script **without** --noupdate or -n then do the drive database update from Storage Manager and finally run the script again with your preferred options.

### Scheduling the script in Synology's Task Scheduler

See <a href=how_to_schedule.md/>How to schedule a script in Synology Task Scheduler</a>

### Running the script via SSH

You run the script in a shell with sudo -i or as root.

```YAML
sudo -i /path-to-script/syno_hdd_db.sh -nr
```

**Note:** Replace /path-to-script/ with the actual path to the script on your Synology.

<p align="leftr"><img src="images/syno_hdd_db1.png"></p>

If you run the script with the --showedits flag it will show you the changes it made to the Synology's compatible-drive database. Obviously this is only useful if you run the script in a shell.

```YAML
sudo -i /path-to-script/syno_hdd_db.sh -nr --showedits
```

**Note:** Replace /path-to-script/ with the actual path to the script on your Synology.

<p align="leftr"><img src="images/syno_hdd_db.png"></p>

**Credits**

- The idea for this script came from a comment made by Empyrealist on the Synology subreddit.
- Thanks for the assistance from Alex_of_Chaos on the Synology subreddit.
- Thanks to dwabraxus and aferende for help detecting connected expansion units.
- Thanks to bartoque on the Synology subreddit for the tip on making the script download the latest release from github.
- Thanks to nicolerenee for pointing out the easiest way to enable creating M.2 storage pools and volumes in Storage Manager.

**Donators**

Thank you to the following PayPal donators, GitHub sponsors and hardware donators

| | | | | 
|--------------------|--------------------|----------------------|----------------------|
| | Mikescher | Matthias Pfaff | cpharada |
| Neil Tapp | zen1605 | Kleissner Investments | Angel Scandinavia |
| bcollins | Peter jackson | Mir Hekmat | Andrew Tapp |
| Peter Weißflog | Joseph Skup | Dirk Kurfuerst | Gareth Locke |
| Rory de Ruijter | Nathan O'Farrell | Harry Bos | Mark-Philipp Wolfger |
| Filip Kraus | John Pham | Alejandro Bribian Rix | Daniel Hofer |
| Bogdan-Stefan Rotariu | Kevin Boatswain | anschluss-org | Yemeth |
| Patrick Thomas | Manuel Marquez Corral | Evrard Franck | Chad Palmer |
| 侯​永政 | CHEN​HAN-YING | Eric Wells | Massimiliano Pesce |
| JasonEMartin | Gerrit Klussmann | Alain Aube | Robert Kraut |
| Charles-Edouard Poisnel | Oliver Busch | anonymous donors | private sponsors |
