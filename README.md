# fmJobMigrate
This is a tool to migrate Plugin Node's FluxMonitor JOB from v2 to v2.4.<br>
Please note that this is still being tested.

# Install the repo
```
git clone https://github.com/AoiToSouma/fmJobMigrate.git
cd fmJobMigrate
```

# npm install
```
npm install
```
The xdc3 npm package will be installed.

# Backup processing
```
./fmJobMigrate.sh 
```
If a FluxMonitor JOB exists, its definition will be saved in the following directory:<br>
```
/plinode_backups/fm_jobs/
```

Filename: fmjob_backup_<jobId>.toml<br>


# Restore processing
At this time, I am testing the v2 Node after a soft reset and have confirmed that JOB can be restored.<br>
I plan to eventually make it possible to register using an automated script in v2.4 Node.<br>
<br>
If you want to restore it manually, you can use the following command:
```
plugin admin login -f apicredentials.txt
plugin jobs create /plinode_backups/fm_jobs/fmjob_backup_<jobId>.toml
```
