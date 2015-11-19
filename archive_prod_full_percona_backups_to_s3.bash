#!/bin/bash
#
# Copy db backup into S3
# set -xv
#

# cron's path
PATH=$PATH:/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin

# set the desired umask
umask 002

# declare variables
EMAIL=bigkahuna@meta.red
LOCAL_BACKUP_DIR=/path/to/backup/dir
S3_BUCKET="s3://aws-s3-link/bucket/"
SERVER_NAME=$(hostname --fqdn)
LOG_DIR=/path/to/log/dir

# make sure our log directory exists
if [ ! -d $LOG_DIR ]; then
  mkdir $LOG_DIR
  if [ ! $? -eq 0 ]; then
    echo "Unable to create log dir: $LOG_DIR" |mail -s "${0}: failed on $SERVER_NAME" $EMAIL
    exit 1
  fi
else
  touch $LOG_DIR/test
  rm $LOG_DIR/test
  if [ ! $? -eq 0 ]; then
    echo "Unable to write to log dir: $LOG_DIR" |mail -s "${0}: failed on $SERVER_NAME" $EMAIL
    exit 1
  fi
fi

# make sure our local backup directory is writable
touch $LOCAL_BACKUP_DIR/test
rm $LOCAL_BACKUP_DIR/test
if [ ! $? -eq 0 ]; then
  echo "Unable to write to backup dir: $LOCAL_BACKUP_DIR" |mail -s "${0}: failed on $SERVER_NAME" $EMAIL
  exit 1
fi

# encrypt local backups for S3 push
cd $LOCAL_BACKUP_DIR
for i in $(find . -type f -daystart -ctime 0 -name "*.gz" | cut -d/ -f2); do
sudo -u gpg_user -i gpg -e --default-recipient 'gpg_key@meta.red' -a ${LOCAL_BACKUP_DIR}/$i
done
if [ ! $? -eq 0 ]; then
  echo "Unable to encrypt backups from $LOCAL_BACKUP_DIR" |mail -s "${0}: failed on $SERVER_NAME" $EMAIL
  exit 1
fi

# retry S3 copy up to 3 times before quitting
# S3 Copy Start Time
S3_START_TIME="$(date)"
for i in $(find . -type f -daystart -ctime 0 -name "*.asc" | cut -d/ -f2); do
sudo -u gpg_user -i aws s3 cp ${LOCAL_BACKUP_DIR}/$i $S3_BUCKET
   if [ ! $? -eq 0 ]; then
       echo "Unable to copy backup file: $i to $S3_BUCKET" |mail -s "${0}: failed on $SERVER_NAME" $EMAIL
       S3_RETRY_COUNT=1
       until [ $S3_RETRY_COUNT -gt 3 ]; do
       echo "Retrying to copy backup file: $i to $S3_BUCKET for attempt number $S3_RETRY_COUNT" |mail -s "${0}: RE-TRY number $S3_RETRY_COUNT on $SERVER_NAME" $EMAIL
       sudo -u gpg_user -i aws s3 cp ${LOCAL_BACKUP_DIR}/$i $S3_BUCKET && break
       S3_RETRY_COUNT=$[$S3_RETRY_COUNT+1]
             if [ $S3_RETRY_COUNT -eq 4 ]; then
                 echo "FAILED 3rd and final attempt to copy backup file: $i to $S3_BUCKET" |mail -s "${0}: FAILED ALL ATTEMPTS to COPY S3 BACKUP $SERVER_NAME" $EMAIL
                 exit 1
             fi
       done
   fi
rm $i
done

# S3 Copy End Time
S3_END_TIME="$(date)"
echo "MYSQL BACKUP S3 COPY STARTED AT: ${S3_START_TIME} FINISHED AT ${S3_END_TIME}"

# clean up any backup files older than 1 day
find ${LOCAL_BACKUP_DIR} -name "*.gz" -type f -mtime +0 -exec rm -f {} \;

exit 0
