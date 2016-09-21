#!/bin/bash
#
# Percona database backup wrapper
#

EMAIL=bigkahuna@meta.red
SERVER_NAME=$(hostname --fqdn)

# email function
notify_email(){
  mail -s "${0}: failed on ${SERVER_NAME}" $EMAIL
}

# Do not fill data volume if S3 copy failed after 3 attempts
# Abort backups
if [ -e /tmp/archive_prod_full_percona_backups_to_s3.test ]; then
  echo "Aborting Backups to avoid filling data volume" |mail -s "S3 Copy failed after 3 attempts on $SERVER_NAME" $EMAIL
  exit 1
fi

## Backup Start Time
START_TIME="$(date)"

# database structure backup
sudo -u mysql /backup_scripts/percona_backup_scripts/percona_prod_structure_database_backup.bash
if [ ! $? -eq 0 ]; then
  echo "percona_prod_structure_database_backup.bash exited with nonzero status" | notify_email
  rm -f /tmp/percona_prod_structure_database_backup.time
  exit 1
fi

# full database backup
sudo -u mysql /backup_scripts/percona_backup_scripts/percona_prod_full_database_backup.bash
if [ ! $? -eq 0 ]; then
  echo "percona_prod_full_database_backup.bash exited with nonzero status" | notify_email
  rm -f /tmp/percona_prod_full_database_backup.time
  exit 1
fi

# compress backups and change perms before S3 copy,removing all but the last local backup
# exit if it fails, fast S3 copy dependent on file compression
/backup_scripts/percona_backup_scripts/compress_prod_full_percona_backups.bash
if [ ! $? -eq 0 ]; then
  echo "compress_prod_full_percona_backups.bash exited with nonzero status" | notify_email
  exit 1
fi

# copy backups to s3/glacier
# Manage test file to stop backups if S3 fails to avoid filling data volume
touch /tmp/archive_prod_full_percona_backups_to_s3.test
/backup_scripts/percona_backup_scripts/archive_prod_full_percona_backups_to_s3.bash
if [ ! $? -eq 0 ]; then
  echo "archive_prod_full_percona_backups_to_s3.bash exited with nonzero status" | notify_email
  END_TIME="$(date)"
  echo "MYSQL DATA BACKUP STARTED AT: ${START_TIME} FINISHED AT ${END_TIME}"
  exit 1
fi
rm -f /tmp/archive_prod_full_percona_backups_to_s3.test

## Backup End Time
END_TIME="$(date)"
echo "MYSQL DATA BACKUP STARTED AT: ${START_TIME} FINISHED AT ${END_TIME}"
