#!/bin/bash
# set -xv
# This is for Mysql Database Backup
# Written By : Richard Lopez
# Date : Nov 4th, 2013
#

# cron's path
PATH=$PATH:/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin

# set the desired umask
umask 002

# declare variables
EMAIL=bigkahuna@meta.red
LOCAL_BACKUP_DIR=/path/to/backup/dir
SERVER_NAME=$(hostname --fqdn)
USERNAME=mysql_backup_user
PASSWORD=mysql_backup_user_pass
LOG_DIR=/path/to/backup/log/dir

# email function
notify_email(){
  mail -s "${0}: failed on ${SERVER_NAME}" $EMAIL
}

# make sure our log directory exists
if [ ! -d $LOG_DIR ]; then
  mkdir $LOG_DIR
  if [ ! $? -eq 0 ]; then
    echo "Unable to create log dir: $LOG_DIR" | notify_email
    exit 1
  fi
else
  touch $LOG_DIR/test
  rm $LOG_DIR/test
  if [ ! $? -eq 0 ]; then
    echo "Unable to write to log dir: $LOG_DIR" | notify_email
    exit 1
  fi
fi

# make sure our local backup directory is writable
if [ ! -d $LOCAL_BACKUP_DIR ]; then
  mkdir -p $LOCAL_BACKUP_DIR
  chown mysql:fx $LOCAL_BACKUP_DIR
  if [ ! $? -eq 0 ]; then
    echo "Unable to create backup dir: $LOCAL_BACKUP_DIR" | notify_email
    exit 1
  fi
else
  touch $LOCAL_BACKUP_DIR/test
  rm $LOCAL_BACKUP_DIR/test
  if [ ! $? -eq 0 ]; then
    echo "Unable to write to backup dir: $LOCAL_BACKUP_DIR" | notify_email
    exit 1
  fi
fi

# Run the Database Backup
innobackupex --rsync --parallel=20 --user=$USERNAME --password=$PASSWORD --safe-slave-backup $LOCAL_BACKUP_DIR

# Find the last Backup Directory for Backup
LAST_BACKUP_DIR=$(ls -tr $LOCAL_BACKUP_DIR|tail -1)


# Apply the log on Backup Directory
innobackupex --apply-log $LOCAL_BACKUP_DIR/$LAST_BACKUP_DIR
