#!/bin/bash
#
# ########################################################################## #
#                                                                            # 
# pitr_globalconf.sh                                                         # 
#                                                                            #
#                                                                            #
# This script has some global bariables and funcions used by                 # 
# pitr_basebackup.sh, pitr_archive_wal.sh and  pitr_archive_last_wal.sh      #
#                                                                            # 
# Copyright (c) 2008-2011 by                                                 #
#                                                                            #
# Rafael Martinez <r.m.guerrero@usit.uio.no>                                 #
# Tommy Gildseth                                                             #
# Roger Johansen <roger.johansen@usit.uio.no>                                #
#                                                                            # 
# USIT, University of Oslo, Norway.                                          #
#                                                                            #
# This script is free software; you can redistribute it and/or modify        #
# it under the terms of the GNU General Public License as published by       #
# the Free Software Foundation; either version 3 of the License, or          #
# (at your option) any later version.                                        #
#                                                                            #
# This script is distributed in the hope that it will be useful,             #
# but WITHOUT ANY WARRANTY; without even the implied warranty of             #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              #
# GNU General Public License for more details.                               #
#                                                                            #
# You should have received a copy of the GNU General Public License          #
# along with Foobar; if not, write to the Free Software                      #
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,                     #
# MA  02110-1301  USA                                                        #
#                                                                            # 
# ########################################################################## #


############################
#### Start editing here ####
############################

# Some unix programs used by this script

AWK="/usr/bin/awk"
BZIP2="/bin/bzip2"
CAT="/bin/cat"
CHMOD="/bin/chmod"
COPY="/bin/cp"
DATE_="/bin/date"
DF="/bin/df"
EGREP="/bin/egrep"
FIND="/usr/bin/find"
GZIP="/bin/gzip"
HEAD="/usr/bin/head"
HOSTNAME="/bin/hostname"
LS="/bin/ls"
LVCREATE="/usr/bin/sudo /sbin/lvcreate"
LVREMOVE="/usr/bin/sudo /sbin/lvremove"
LVDISPLAY="/usr/bin/sudo /sbin/lvdisplay"
MAIL="/bin/mail"
MKDIR="/bin/mkdir"
MOUNT="/usr/bin/sudo /bin/mount"
REMOVE="/bin/rm"
SED="/bin/sed"
SORT="/usr/bin/sort"
STAT="/usr/bin/stat"
TAR="/bin/tar"
TEE="/usr/bin/tee -a"
TR="/usr/bin/tr"
UMOUNT="/usr/bin/sudo /bin/umount"
VGDISPLAY="/usr/bin/sudo /sbin/vgdisplay"
XARGS="/usr/bin/xargs"

# Directory with PostgreSQL software 
PG_DIR="/usr/local/bin"

# PostgreSQL client
PSQL=$PG_DIR/psql

# Directory used for postgresql sockets
PG_SOCKETS=/tmp

# LVM LV - Data
DEV_DATA_PARTITION=/dev/vg01_data/pg_data

# LVM Snapshot name used with PITR basebackup 
PITR_SNAPSHOT_NAME="pitr_snapshot"

# LVM LV - data snapshot
DEV_PITR_SNAPSHOT_PARTITION=/dev/vg01_data/${PITR_SNAPSHOT_NAME}

# Data partition used by PostgreSQL 
PG_DATA_PARTITION="/var/lib/pgsql/pg_data"

# Partitition used by PostgreSQL to save WAL files
PG_ARCH_PARTITION="/var/lib/pgsql/pg_xlog"

# Partition used by PostgreSQL to save logfiles
PG_LOGS_PARTITION="/var/lib/pgsql/pg_logs"

# Backup  partition for our postgresql cluster
PG_BACKUP_PARTITION="/var/lib/pgsql/pg_bck"

# Directory for PITR base backups 
PG_BACKUP_PITR_DATA=${PG_BACKUP_PARTITION}/PITR_data

# Directory used to take a backup of the WAL generated
PG_BACKUP_PITR_WAL=${PG_BACKUP_PARTITION}/PITR_wal

# Directory used to take a backup of the last WAL file in use
PG_BACKUP_PITR_LAST=${PG_BACKUP_PARTITION}/PITR_last_wal

# Mount point for LVM snapshot 
PG_BACKUP_PITR_SNAPSHOT=${PG_BACKUP_PARTITION}/PITR_snapshot

# Control file used by PITR basebackup
BACKUP_LABEL_FILE=${PG_DATA_PARTITION}/backup_label

# Message at the botton of the e-mails sent by this script.
BACKUP_LOG_ERROR_MESSAGE_BOTTOM="More information about PostgreSQL can be found at:
http://www.postgresql.org/"

# Compression format used with PITR backup files [bzip2|gzip]
BACKUP_COMPRESSION_FORMAT="gzip"

# Backup default retention period 
BACKUP_DEFAULT_RETENTION_PERIOD="3 days"

# E-mail address used to received error e-mails.
ADMIN_EMAIL="user@example.com"

# Error e-mails will be sent only every $EMAIL_INTERVAL seconds
let EMAIL_INTERVAL=3600


############################
#### Stop editing here  ####
############################

VERSION="5.2"

# Control file used to avoid an e-mail storm from PostgreSQL
STOP_EMAIL_STORM=${PG_LOGS_PARTITION}/STOP_EMAIL_STORM

HOSTNAME_LONG=`$HOSTNAME`
DATE_TIME=$($DATE_ "+%d/%m/%Y %H:%M:%S")
FILE_ID=$($DATE_ +%Y-%m-%d_%H%M%S)

# PostgreSQl version
PGVERSION=`$PSQL --quiet -U postgres -h $PG_SOCKETS -c "SELECT substring(version(), '^PostgreSQL ((.*).(.*).(.*)) on')" -P tuples_only -P format=unaligned | $TR -d "[:space:]"`

NO_ARGS=0 
E_OPTERROR=65
FORCE=0

# ########################################
# ########################################
#
# Function sendmail()
# Used to send e-mail to $ADMIN_EMAIL
#
# Parameters:
# $1 Message body
# $2 Subject
#
# ########################################
# ########################################

sendmail(){

    MESSAGE=$1
    SUBJECT=$2

    echo "$MESSAGE" | $MAIL -s "$SUBJECT" $ADMIN_EMAIL
}

