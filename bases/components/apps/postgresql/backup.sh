#!/bin/bash
set -e

# TODO 
# - allow setting of retention days, backup dir via enva
# - calculate the size of DB and free space and error/message if insufficient space
DIR="/var/lib/pgsql/backups"
FILE_BASE="${DIR}/${POSTGRESQL_DATABASE}"
DB_URL="postgresql://${POSTGRESQL_USER}:${POSTGRESQL_PASSWORD}@postgresql:5432/${POSTGRESQL_DATABASE}"

function do_backup() {
    if [[ $(date +%d) = "01" ]] ; then
        FILE="${FILE_BASE}-monthly-$(date +"%F").dump.gz"
    elif [[ $(date +%u) = "7" ]] ; then
        FILE="${FILE_BASE}-weekly-$(date +"%F").dump.gz"
    else
        FILE="${FILE_BASE}-daily-$(date +"%F").dump.gz"
    fi

    echo -n "Dumping ${POSTGRESQL_DATABASE} DB to ${FILE}... "
    pg_dump -Fc --dbname=${DB_URL} | gzip > ${FILE}
    echo "done."

}

function prune_old_files() {
    echo -n "Removing old backups if necessary according to simple retention schedule... "
    find ${FILE_BASE}-monthly* -mtime +365 -delete 2> /dev/null || true
    find ${FILE_BASE}-weekly* -mtime +120 -delete 2> /dev/null || true
    find ${FILE_BASE}-daily* -mtime +14 -delete 2> /dev/null || true
    echo "done."
}

prune_old_files
do_backup
