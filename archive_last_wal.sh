#!/bin/bash
#                                                                             
# ########################################################################## #
#                                                                            # 
# archive_last_wal.sh                                                        # 
#                                                                            #
# This script is used to archive the last WAL file under pg_xlog             #
# still not archived by Postgresql. It is executed by cron every minute.     #
# In the worst case scenario we can lose the last minute with transactions   #
# if we lose the pg_xlog diskarray completely and PITR is activated.         #
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
# Function last_wal()
#
# Copies the last WAL file under $PG_ARCH_PARTITION
# not archived yet to $PG_BACKUP_PITR_LAST
#
# This file gets old and useless very fast 
# in a heavy updated cluster.
#
# It is very usefull in a cluster with not 
# many updates. WAL files have to be 16MB
# before they get archived.
# ########################################
# ########################################
last_wal(){
    
    LASTWAL=`$LS -tp $PG_ARCH_PARTITION/ | $EGREP -v '(backup|lost|SECURITY|archive_status)' | $HEAD -1`

    if ! $COPY $PG_ARCH_PARTITION/$LASTWAL $PG_BACKUP_PITR_LAST > /dev/null 2>&1
	then

	message="
-------------------------------------------------------------------------
Host: $HOSTNAME_LONG
Service host / SG package: $SERVICE_HOSTNAME
Date: $DATE_TIME
-------------------------------------------------------------------------

WARNING - Could not copy last WAL file (maybe not archived) 
$PG_ARCH_PARTITION/$LASTWAL
to
$PG_BACKUP_PITR_LAST

Logfile:
$PITR_LASTWAL_LOG

$BACKUP_LOG_ERROR_MESSAGE_BOTTOM
-------------------------------------------------------------------------
"
	
        sendmail "$message" "[WARNING: ${SERVICE_HOSTNAME}] - Could not copy last WAL"

	echo -e "* WARNING: Could not copy last WAL" | $TEE $PITR_LASTWAL_LOG
    fi
}


# ########################################
# ########################################
# Function remove_last_wal()
#
# Removes old last WAL files under
# $PG_BACKUP_PITR_LAST
#
# ########################################
# ########################################

remove_last_wal(){

    if ! $REMOVE -f $PG_BACKUP_PITR_LAST/* > /dev/null 2>&1
	then
	message="
Host: $HOSTNAME_LONG
Service host / SG package: $SERVICE_HOSTNAME
Date: $DATE_TIME
-------------------------------------------------------------------------

WARNING - Could not remove old last WAL files under 
$PG_BACKUP_PITR_LAST

Logfile:
$PITR_LASTWAL_LOG

$BACKUP_LOG_ERROR_MESSAGE_BOTTOM
-------------------------------------------------------------------------
"
	sendmail "$message" "[WARNING: ${SERVICE_HOSTNAME}] - Could not remove old last WAL"
	
	echo -e "* WARNING: Could not remove old last WAL" | $TEE $PITR_LASTWAL_LOG
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
Description: This script is used to archive the last WAL file under pg_xlog  
             still not archived by PostgreSQL. It is executed by cron every minute. 
             In the worst case scenario we can lose the last minute with transactions
             if we lose the pg_xlog diskarray completely and PITR is activated."

    echo
    echo "Usage: "
    echo "       `basename $0` [-v][-h][-S service_hostname][-j jobID]"
    echo 
    echo "       -h Help"
    echo "       -v Version"
    echo "       -S Hostname/SG package running postgreSQL (*)"
    echo 
    echo "       (*) - Must be defined"
    echo 
    echo "Example: `basename $0` -S dbpg-example -j 200"
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
while getopts "hvS:" Option
  do
  case $Option in
      h) 
	  help
	  exit 0;;
      
      v)
	  echo 
	  echo " Name: `basename $0`"
	  echo " Version: ${VERSION}"
	  echo " Description: Archive last WAL file script"
	  echo " Contact: postgres-core@usit.uio.no"
	  echo
	  exit 0;;
    
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

if [ -z $SERVICE_HOSTNAME ]
    then
    echo "Error: Hostname/SG package not defined"
    echo
    
    help    
    sendmail "ERROR: Hostname/SG package not defined" "[ERROR: $HOSTNAME_LONG] - Hostname/SG package not defined"

    exit $E_OPTERROR   
fi




PITR_LASTWAL_LOG=$PG_LOGS/pitr_last_wal-${FILE_ID}.log


if [ -f ${PG_DATA_PARTITION}/data/postmaster.pid ]; then
    remove_last_wal
    last_wal
fi

exit 0

#
# EOF
#
