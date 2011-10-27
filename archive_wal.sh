#!/bin/bash
#
# ########################################################################## #
#                                                                            # 
# archive_wal.sh                                                             # 
#                                                                            #
# This script is used by postgresql.conf:archive_command to archive          #
# WAL files to pg_bck/PITR_wal                                               #
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


PWD_SOURCE=`dirname $0`
source "${PWD_SOURCE}/pitr_globalconf.sh"


# ########################################
# ########################################
# Function check_partition()
# 
# Check if $PG_BACKUP_PITR_WAL and 
# $PG_ARCH_PARTITION exists.
#
# Script is aborted if they do not exist.
#
# ########################################
# ########################################

check_partitions(){

    if [ ! -d $PG_BACKUP_PITR_WAL ]; then

	LAST_EMAIL=`$CAT $STOP_EMAIL_STORM 2> /dev/null`
	
	if [ -z $LAST_EMAIL ]; then
	    let INTERVAL=$EMAIL_INTERVAL+1
	else
	    let LAST_EMAIL=`$CAT $STOP_EMAIL_STORM 2> /dev/null`
	    let INTERVAL=$TIMESTAMP-$LAST_EMAIL
	fi
	
	if [ $INTERVAL -lt $EMAIL_INTERVAL ]; then
	    exit 1
	fi
	
	message="
-------------------------------------------------------------------------
Host: $HOSTNAME_LONG
Service host / SG package: $SERVICE_HOSTNAME
Date: $DATE_TIME

Script: pgclarchive_wal.sh
-------------------------------------------------------------------------

ERROR: $PG_BACKUP_PITR_WAL does not exist. pgclarchive_wal.sh can not archive 
the WAL file $WAL_FILE under $PG_BACKUP_PITR_WAL.

$BACKUP_LOG_ERROR_MESSAGE_BOTTOM
-------------------------------------------------------------------------
"
	
        sendmail "$message" "[ERROR: ${SERVICE_HOSTNAME}] $PG_BACKUP_PITR_WAL does not exist"

        echo $TIMESTAMP > $STOP_EMAIL_STORM
	sleep 5
        exit 1
    fi
    
    if [ ! -d $PG_ARCH_PARTITION ]; then

	LAST_EMAIL=`$CAT $STOP_EMAIL_STORM 2> /dev/null`
	
	if [ -z $LAST_EMAIL ]; then
	    let INTERVAL=$EMAIL_INTERVAL+1
	else
	    let LAST_EMAIL=`$CAT $STOP_EMAIL_STORM 2> /dev/null`
	    let INTERVAL=$TIMESTAMP-$LAST_EMAIL
	fi
	
	if [ $INTERVAL -lt $EMAIL_INTERVAL ]; then
	    exit 1
	fi
	
	message="
-------------------------------------------------------------------------
Host: $HOSTNAME_LONG
Service host / SG package: $SERVICE_HOSTNAME
Date: $DATE_TIME

Script: pgclarchive_wal.sh
-------------------------------------------------------------------------
	
ERROR: $PG_ARCH_PARTITION does not exist. pgclarchive_wal.sh can not read
the WAL file $WAL_FILE to be archived.
	
This is a serious error. Probably your PostgreSQL cluster will crash.

$BACKUP_LOG_ERROR_MESSAGE_BOTTOM
-------------------------------------------------------------------------
"
	
        sendmail "$message" "[ERROR: ${SERVICE_HOSTNAME}] $PG_ARCH_PARTITION does not exist"
        
	echo $TIMESTAMP > $STOP_EMAIL_STORM
	sleep 5
	exit 1
    fi
}



# ########################################
# ########################################
#
# Function check_wal_file()
#
# Checks if the file to be copied to 
# PITR_wal exists. We exit the script with 
# a non-zero value (error) if it does.
#
# ########################################
# ########################################

check_wal_file(){
    
    if [ -f "$PG_BACKUP_PITR_WAL/$WAL_FILE" ]; then
	
	LAST_EMAIL=`$CAT $STOP_EMAIL_STORM 2> /dev/null`
	
	if [ -z $LAST_EMAIL ]; then
	    let INTERVAL=$EMAIL_INTERVAL+1
	else
	    let LAST_EMAIL=`$CAT $STOP_EMAIL_STORM 2> /dev/null`
	    let INTERVAL=$TIMESTAMP-$LAST_EMAIL
	fi
	
	if [ $INTERVAL -lt $EMAIL_INTERVAL ]; then
	    exit 1
	fi
	
	message="
-------------------------------------------------------------------------
Host: $HOSTNAME_LONG
Service host / SG package: $SERVICE_HOSTNAME
Date: $DATE_TIME

Script: pgclarchive_wal.sh
-------------------------------------------------------------------------

ERROR: WAL $WAL_FILE already exist under $PG_BACKUP_PITR_WAL.
archive_wal.sh refuses to overwrite this file to preserve the integrity 
of your archive.

This is a serious error that should not happen. You should investigate 
the cause (probably a bug or an administrator error) and fix it. 

This e-mail is only sent every $EMAIL_INTERVAL sec. to avoid an e-mail storm
from postgreSQL archive system.

$BACKUP_LOG_ERROR_MESSAGE_BOTTOM 
-------------------------------------------------------------------------
"
	
	sendmail "$message" "[ERROR: ${SERVICE_HOSTNAME}] WAL $WAL_FILE already exist"
	
	if [ -f "${PG_ARCH_PARTITION}/archive_status/${WAL_FILE}.done" ] && [ -f "${PG_ARCH_PARTITION}/archive_status/${WAL_FILE}.ready" ]; then
	    
	    if $REMOVE -f ${PG_ARCH_PARTITION}/archive_status/${WAL_FILE}.ready
		then
		
		message="
-------------------------------------------------------------------------
Host: $HOSTNAME_LONG
Service host / SG package: $SERVICE_HOSTNAME
Date: $DATE_TIME

Script: pgclarchive_wal.sh
-------------------------------------------------------------------------

ERROR: ${PG_ARCH_PARTITION}/archive_status/${WAL_FILE}.done and 
${PG_ARCH_PARTITION}/archive_status/${WAL_FILE}.ready exist at the same time.

This should not happen, probably an OS or postgresql bug. 
${PG_ARCH_PARTITION}/archive_status/${WAL_FILE}.ready has been deleted.

More information:
http://archives.postgresql.org/pgsql-hackers/2006-05/msg01280.php

$BACKUP_LOG_ERROR_MESSAGE_BOTTOM 
-------------------------------------------------------------------------
"
		
		sendmail "$message" "[OK: ${SERVICE_HOSTNAME}] Deleting archive_status/${WAL_FILE}.ready"
	    else
		message="
-------------------------------------------------------------------------
Host: $HOSTNAME_LONG
Service host / SG package: $SERVICE_HOSTNAME
Date: $DATE_TIME

Script: pgclarchive_wal.sh
-------------------------------------------------------------------------

ERROR: ${PG_ARCH_PARTITION}/archive_status/${WAL_FILE}.done and 
${PG_ARCH_PARTITION}/archive_status/${WAL_FILE}.ready exist at the same time.

This should not happen, probably an OS or postgresql bug. 
${PG_ARCH_PARTITION}/archive_status/${WAL_FILE}.ready could not be deleted

More information:
http://archives.postgresql.org/pgsql-hackers/2006-05/msg01280.php

$BACKUP_LOG_ERROR_MESSAGE_BOTTOM 
-------------------------------------------------------------------------
"
		
		sendmail "$message" "[ERROR: ${SERVICE_HOSTNAME}] archive_status/${WAL_FILE}.ready could not be deleted"
	    fi
	fi
	
	echo $TIMESTAMP > $STOP_EMAIL_STORM
	sleep 5
	exit 1
    fi
}


# ########################################
# ########################################
#
# Function archive_wal()
#
# It will try to copy a wal file to the 
# PG_BACKUP_PITR_WAL. It returns a non-zero 
# value if error
# 
# ########################################
# ########################################

archive_wal(){

    if  $COPY -dp $ABSOLUTE_PATH $PG_BACKUP_PITR_WAL/$WAL_FILE
	then
	
	$CHMOD 400 $PG_BACKUP_PITR_WAL/$WAL_FILE
    else

	LAST_EMAIL=`$CAT $STOP_EMAIL_STORM 2> /dev/null`
	
	if [ -z $LAST_EMAIL ]; then
	    let INTERVAL=$EMAIL_INTERVAL+1
	else
	    let LAST_EMAIL=`$CAT $STOP_EMAIL_STORM 2> /dev/null`
	    let INTERVAL=$TIMESTAMP-$LAST_EMAIL
	fi
	
	if [ $INTERVAL -lt $EMAIL_INTERVAL ]; then
	    exit 1
	fi
	
	$message ="
-------------------------------------------------------------------------
Host: $HOSTNAME_LONG
Service host / SG package: $SERVICE_HOSTNAME
Date: $DATE_TIME

Script: pgclarchive_wal.sh
-------------------------------------------------------------------------
	
ERROR - WAL $WAL_FILE could not be archived under $PG_BACKUP_PITR_WAL. 
The  directory $PG_ARCH_PARTITION will continue to fill with WAL segment 
files not archived until the situation is resolved.
	
This e-mail is only sent every $EMAIL_INTERVAL sec. to avoid an e-mail storm
from postgreSQL archive system.

$BACKUP_LOG_ERROR_MESSAGE_BOTTOM
-------------------------------------------------------------------------
"
	
	sendmail "$message" "[ERROR: ${SERVICE_HOSTNAME}] WAL $WAL_FILE could not be archived"
	echo $TIMESTAMP > $STOP_EMAIL_STORM
	
	sleep 5
        exit 1
    fi
}


# ########################################
# ########################################
# MAIN
# ########################################
# ########################################

help(){

    echo
    echo "Script: $0" 
    echo "Version: ${VERSION}"
    
    echo "
Description: This script is used by postgresql.conf:archive_command to archive
             WAL files to pg_bck/PITR_wal "

    echo 
    echo "Usage: "
    echo "       `basename $0` [-v][-h][-P Absolute path of WAL][-F WAL Filename][-S service_hostname]"
    echo 
    echo "       -h Help"
    echo "       -v Version"
    echo "       -P Absolute path of WAL to archive (*)"
    echo "       -F WAL Filename to archive (*)"
    echo "       -S Hostname/SG package running postgreSQL (*)"
    echo
    echo "       (*) - Must be defined"
    echo
    echo "Example: archive_command = '$0 -P %p -F %f -S dbpg-example'"
    echo 
}


# ########################################
# ########################################
# Script invoked with no command-line args?
# ########################################
# ########################################
if [ $# -eq "$NO_ARGS" ]
    then
    help
    exit $E_OPTERROR   
fi  


# ########################################
# ########################################
# Getting command options
# ########################################
# ########################################
while getopts "hvP:F:S:" Option
  do
  case $Option in
      h) 
	  help
	  exit 0;;
    
      v)
	  echo
	  echo " Name: `basename $0`"
	  echo " Version: $VERSION"
	  echo " Description: Archive WAL files script"
	  echo " Contact: postgres-core@usit.uio.no"
	  echo
	  exit;;
    
      P)
    ABSOLUTE_PATH=$OPTARG;;
  
      F)
    WAL_FILE=$OPTARG;;
    
      S) 
    SERVICE_HOSTNAME=$OPTARG;;
     
  esac
done 
shift $(($OPTIND - 1))

# ########################################
# ########################################
# Sanity check
# ########################################
# ########################################
if [ -z $ABSOLUTE_PATH ]
    then
    echo "Error: Absolute path not defined"
    echo
    sendmail "ERROR: Absolute path not defined" "ERROR:${SERVICE_HOSTNAME} - Absolute path not defined"
    exit $E_OPTERROR   
fi
  
if [ -z $WAL_FILE ]
    then
    echo "Error: WAL filename not defined"
    echo
    sendmail "ERROR: WAL filename not defined" "ERROR:${SERVICE_HOSTNAME} - WAL filename not defined"
    exit $E_OPTERROR   
fi  

if [ -z $SERVICE_HOSTNAME ]
    then
    echo "Error: Hostname/SG package not defined"
    echo
    sendmail "ERROR: Hostname/SG package not defined" "ERROR:${HOSTNAME_LONG} - Hostname/SG package not defined"

    exit $E_OPTERROR   
fi


check_wal_file
check_partitions
archive_wal

exit 0

#
# EOF