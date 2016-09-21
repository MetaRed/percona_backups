#!/bin/bash
#
# Compress prod db amz backups
#

# cron's path
PATH=$PATH:/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin

# set the desired umask
umask 002

# declare variables
BACKUP_DATE=$(date +%Y%m%d)
EMAIL=bigkahuna@meta.red
LOCAL_BACKUP_DIR=/path/to/backup/dir
SERVER_NAME=$(hostname --fqdn)
LOG_DIR=/path/to/mysql/log/dir

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
touch $LOCAL_BACKUP_DIR/test
rm $LOCAL_BACKUP_DIR/test
if [ ! $? -eq 0 ]; then
  echo "Unable to write to backup dir: $LOCAL_BACKUP_DIR" | notify_email
  exit 1
fi

# Find the Current Backup Directory for Backup
cd $LOCAL_BACKUP_DIR
CURRENT_BACKUP_DIR=$(find . -maxdepth 1 -type d -mtime 0 | tail -1 | cut -d/ -f2)
if [ ! $? -eq 0 ]; then
  echo "Unable to find last backup dir under $LOCAL_BACKUP_DIR" | notify_email
  exit 1
fi

# tar up the current backup dir for ease of transport
cd $LOCAL_BACKUP_DIR
tar --remove-files -I pigz -cvf ${SERVER_NAME}-${CURRENT_BACKUP_DIR}.tar.gz ${CURRENT_BACKUP_DIR}
if [ ! $? -eq 0 ]; then
  echo "Unable to tar up the current backup ${LOCAL_BACKUP_DIR}/${SERVER_NAME}-${CURRENT_BACKUP_DIR}" | notify_email
  exit 1
fi

# change ownership for encryption
cd $LOCAL_BACKUP_DIR
chown gpg_user:gpg_user ${SERVER_NAME}-${CURRENT_BACKUP_DIR}.tar.gz
if [ ! $? -eq 0 ]; then
  echo "Unable to change ownership of the current backup $LOCAL_BACKUP_DIR/${SERVER_NAME}-$CURRENT_BACKUP_DIR" | notify_email
  exit 1
fi

# find the current structure backup
cd ${LOCAL_BACKUP_DIR}
CURRENT_SQLDUMP_FILE=$(find . -maxdepth 1 -type f -name "*prod_structure_backup.sql" -mtime 0 | cut -d/ -f2)
if [ ! $? -eq 0 ]; then
  echo "Unable to find the current sql dump file ${CURRENT_SQLDUMP_FILE}" | notify_email
fi

# compress the current structure backup
gzip ${CURRENT_SQLDUMP_FILE}
if [ ! $? -eq 0 ]; then
  echo "Unable to gzip the current sql dump file ${CURRENT_SQLDUMP_FILE}" | notify_email
  exit 1
fi

# change ownership for encryption
chown gpg_user:gpg_user ${CURRENT_SQLDUMP_FILE}.gz
mv ${CURRENT_SQLDUMP_FILE}.gz ${SERVER_NAME}-${BACKUP_DATE}-${CURRENT_SQLDUMP_FILE}.gz

exit 0
