#!/bin/bash
# set -xv
# This is for Mysql Database Structure Backup
# Written By : Richard Lopez
# Date : Dec 16th, 2013
#

# cron's path
PATH=$PATH:/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin

# set the desired umask
umask 002

# declare variables
DATE=$(date +%Y%m%d)
EMAIL=bigkahuna@meta.red
LOCAL_BACKUP_DIR=/path/to/backup/dir
SQLDUMP_FILE=${LOCAL_BACKUP_DIR}/${DATE}_prod_structure_backup.sql
SERVER_NAME=$(hostname --fqdn)
USERNAME=mysql_dump_user
PASSWORD=mysql_dump_user_pass
LOG_DIR=/path/to/backup/log/dir

# make sure our log directory exists
if [ ! -d $LOG_DIR ]; then
  mkdir $LOG_DIR
  if [ ! $? -eq 0 ]; then
    echo "Unable to create log dir: $LOG_DIR" |mail -s "${0}: failed" $EMAIL
    exit 1
  fi
else
  touch $LOG_DIR/test
  rm $LOG_DIR/test
  if [ ! $? -eq 0 ]; then
    echo "Unable to write to log dir: $LOG_DIR" |mail -s "${0}: failed" $EMAIL
    exit 1
  fi
fi

# make sure our local backup directory exists and is writable
if [ ! -d $LOCAL_BACKUP_DIR ]; then
  mkdir -p $LOCAL_BACKUP_DIR
  chown mysql:fx $LOCAL_BACKUP_DIR
  if [ ! $? -eq 0 ]; then
    echo "Unable to create log dir: $LOCAL_BACKUP_DIR" |mail -s "${0}: failed" $EMAIL
    exit 1
  fi
else
  touch $LOCAL_BACKUP_DIR/test
  rm $LOCAL_BACKUP_DIR/test
  if [ ! $? -eq 0 ]; then
  echo "Unable to write to backup dir: $LOCAL_BACKUP_DIR" |mail -s "${0}: failed" $EMAIL
  exit 1
  fi
fi

# Run the Structure Database Backup
mysqldump --no-data --all-databases -u $USERNAME -p$PASSWORD --single-transaction >$SQLDUMP_FILE
if [ ! $? -eq 0 ]; then
  echo "Unable to create MYSQL structure backup on $LOCAL_BACKUP_DIR" |mail -s "${0}: failed" $EMAIL
  exit 1
fi

