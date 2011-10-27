#!/bin/bash
#
# ########################################################################## #
#                                                                            # 
# pitr_basebackup.sh                                                         # 
#                                                                            #
# This script is used to create a base backup of PGDATA                      #
# that can be used by PITR to restore the database cluster.                  #
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
#
# Function check_partition()
# We check that PITR_data exists and has 
# an estimated final disk space available
# larger than 5% of the total space
#
# Script is aborted if PITR_data does not exist.
# or the disk space estimation thinks 
# the script will not have enough free disk space
# to take a pitr basebackup
#
# ########################################
# ########################################

check_partitions(){
    
    
#
# Check if $PG_BACKUP_PITR_DATA exists. 
# If not, try to create it.
#
    
    if [ ! -d $PG_BACKUP_PITR_DATA ]; then

	if $MKDIR -p $PG_BACKUP_PITR_DATA >> $PITR_BASEBACKUP_LOG 2>&1
	then
	    TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`

	    echo -e "${TIMESTAMP} [OK] Directory $PG_BACKUP_PITR_DATA created" >> $PITR_BASEBACKUP_LOG
	    OUTPUT=${OUTPUT}"${TIMESTAMP} [OK] Directory $PG_BACKUP_PITR_DATA created
"
	else
	    
	    message="
-------------------------------------------------------------------------
Host: $HOSTNAME_LONG
Service host / SG package: $SERVICE_HOSTNAME
Date: $DATE_TIME
-------------------------------------------------------------------------

ERROR: $PG_BACKUP_PITR_DATA does not exist. pgclpitr_basebackup.sh can not create 
	a base backup under $PG_BACKUP_PITR_DATA.

Logfile:
$PITR_BASEBACKUP_LOG

$BACKUP_LOG_ERROR_MESSAGE_BOTTOM
-------------------------------------------------------------------------"
	    
            sendmail "$message" "[ERROR: ${SERVICE_HOSTNAME}] - $PG_BACKUP_PITR_DATA does not exist"
	    
	    TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`

	    echo -e "${TIMESTAMP} [ERROR] Partition $PG_BACKUP_PITR_DATA does not exist" >> $PITR_BASEBACKUP_LOG
            exit 1
	fi
    else
	TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
	
	echo -e "${TIMESTAMP} [OK] Partition $PG_BACKUP_PITR_DATA checked" >> $PITR_BASEBACKUP_LOG
	OUTPUT=${OUTPUT}"${TIMESTAMP} [OK] Partition $PG_BACKUP_PITR_DATA checked
"
    fi
    
    
#
# Check disk space available under $PG_BACKUP_PARTITION
#

# 
# PITR_DATA_USED = bytes used by $PG_BACKUP_PARTITION
# PITR_DATA_AVAILABLE = bytes available under $PG_BACKUP_PARTITION
# FIFTY_PORCENT_PG_DATA_USED = 50% of bytes used by $PG_DATA_PARTITION
# FIVE_PORCENT_PITR_DATA_DISK = 5% of total bytes under $PG_BACKUP_PARTITION
#
# FINAL_ESTIMATED_AVAILABLE_DISKSPACE = Final disk space available under $PG_BACKUP_PARTITION when running PITR 
#                                       if we estimate to use 50% of the disk space used by $PG_DATA_PARTITION
#
# If FINAL_ESTIMATED_AVAILABLE_DISKSPACE < FIVE_PORCENT_PITR_DATA_DISK, stop running PITR. 
#

    
    let PITR_DATA_USED=`$DF $PG_BACKUP_PARTITION | $EGREP "([0-9])%" | $AWK -F' ' '{print $4}' | $AWK -F'%' '{print $1}'`

    let PITR_DATA_AVAILABLE=`$DF $PG_BACKUP_PARTITION | $EGREP "([0-9])%" | $AWK -F' ' '{print $3}'`
    let FIFTY_PORCENT_PG_DATA_USED=`$DF $PG_DATA_PARTITION | $EGREP "([0-9])%" | $AWK -F' ' '{print $2}'`*50/100
    let FIVE_PORCENT_PITR_DATA_DISK=`$DF $PG_BACKUP_PARTITION | $EGREP "([0-9])%" | $AWK -F' ' '{print $1}'`*5/100
    
    let FINAL_ESTIMATED_AVAILABLE_DISKSPACE=(${PITR_DATA_AVAILABLE}-${FIFTY_PORCENT_PG_DATA_USED})
    
    if [ $FINAL_ESTIMATED_AVAILABLE_DISKSPACE -lt $FIVE_PORCENT_PITR_DATA_DISK ]; then
	
	message="
-------------------------------------------------------------------------
Host: $HOSTNAME_LONG
Service host / SG package: $SERVICE_HOSTNAME
Date: $DATE_TIME
-------------------------------------------------------------------------

WARNING: We have estimated that the maximum available disk space during
PITR base backup will be less than 5% of the available disk space under    
$PG_BACKUP_PARTITION

This partition should not get full and this PITR base backup job 
has been aborted to avoid problems under this backup job.

Max.avaliable disk space during PITR base backup: ${FINAL_ESTIMATED_AVAILABLE_DISKSPACE}
5% of avaliable disk space = ${FIVE_PORCENT_PITR_DATA_DISK}

Logfile:
$PITR_BASEBACKUP_LOG

$BACKUP_LOG_ERROR_MESSAGE_BOTTOM
-------------------------------------------------------------------------"

	sendmail "$message" "[WARNING: ${SERVICE_HOSTNAME}] - PITR base backup job has been aborted"

	TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`

	echo -e "${TIMESTAMP} [WARNING] Estimated disk space needed larger than the available disk space under $PG_BACKUP_PITR_DATA. / ${PITR_DATA_AVAILABLE} / ${FIFTY_PORCENT_PG_DATA_USED} / ${FINAL_ESTIMATED_AVAILABLE_DISKSPACE} / ${FIVE_PORCENT_PITR_DATA_DISK}" >> $PITR_BASEBACKUP_LOG
	exit 1;
    else
	TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`

	echo -e "${TIMESTAMP} [OK] Partition $PG_BACKUP_PITR_DATA available disk space checked / ${PITR_DATA_AVAILABLE} / ${FIFTY_PORCENT_PG_DATA_USED} / ${FINAL_ESTIMATED_AVAILABLE_DISKSPACE} / ${FIVE_PORCENT_PITR_DATA_DISK}" >> $PITR_BASEBACKUP_LOG
	OUTPUT=${OUTPUT}"${TIMESTAMP} [OK] Partition $PG_BACKUP_PITR_DATA available disk space checked / ${PITR_DATA_AVAILABLE} / ${FIFTY_PORCENT_PG_DATA_USED} / ${FINAL_ESTIMATED_AVAILABLE_DISKSPACE} / ${FIVE_PORCENT_PITR_DATA_DISK} 
"
	
    fi

}


# ########################################
# ########################################
# Function check_basebackup_file()
#
# Check if $BACKUP_LABEL_FILE exists.
#
# This file exists if a basebackup is running
# or if a basebackup finnish with an error/crash
# without removing $BACKUP_LABEL_FILE
#
# We try to cleanup and remove $BACKUP_LABEL_FILE 
# if a basebackup finish with an error or crash.
#
# Script is aborted if $BACKUP_LABEL_FILE exists.
# ########################################
# ########################################

check_basebackup_file(){

    if [ -e "$BACKUP_LABEL_FILE" ]; then
	message="
-------------------------------------------------------------------------
Host: $HOSTNAME_LONG
Service host / SG package: $SERVICE_HOSTNAME
Date: $DATE_TIME
-------------------------------------------------------------------------

ERROR: A PITR base backup is already in progress.  PITR base backup aborted.

If you're sure there is no backup in progress, remove the file
$BACKUP_LABEL_FILE and try again.

Logfile:
$PITR_BASEBACKUP_LOG

$BACKUP_LOG_ERROR_MESSAGE_BOTTOM
-------------------------------------------------------------------------"

        sendmail "$message" "[ERROR: ${SERVICE_HOSTNAME}] - A PITR base backup is already in progress."
 
	TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`

	echo -e "${TIMESTAMP} [ERROR] A PITR base backup is already in progress" >> $PITR_BASEBACKUP_LOG
	exit 1
    else
	TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`

	echo -e "${TIMESTAMP} [OK] Backup label file checked" >> $PITR_BASEBACKUP_LOG
	OUTPUT=${OUTPUT}"${TIMESTAMP} [OK] Backup label file checked
"
    fi
}


# ########################################
# ########################################
# Function start_backup()
#
# Runs "SELECT pg_start_backup('$PITR_BASEBACKUP_ID');"
# to register that a basebackup has been startet.
#
# It calls base_backup() if succeeded.
#
# Script is aborted if this command returns an error
#
# ########################################
# ########################################

start_backup(){

    if WAL_LOCATION_START=`$PSQL --quiet -U postgres -h $PG_SOCKETS -c "SELECT pg_start_backup('$PITR_BASEBACKUP_ID');" -P tuples_only -P format=unaligned 2>> $PITR_BASEBACKUP_LOG`
	then
	TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`

	WAL_ID_START=`$PSQL --quiet -U postgres -h $PG_SOCKETS -c "SELECT pg_xlogfile_name('${WAL_LOCATION_START}');" -P tuples_only -P format=unaligned 2>> $PITR_BASEBACKUP_LOG`

	PITR_BASEBACKUP_ID=${PITR_BASEBACKUP_ID}_bckid${WAL_ID_START}

	echo -e "${TIMESTAMP} [OK] Backup process started" >> $PITR_BASEBACKUP_LOG
	OUTPUT=${OUTPUT}"${TIMESTAMP} [OK] Backup process started
"
    else
	message="
-------------------------------------------------------------------------
Host: $HOSTNAME_LONG
Service host / SG package: $SERVICE_HOSTNAME
Date: $DATE_TIME
-------------------------------------------------------------------------

ERROR:  pg_start_backup() returns an error. 

Base backup aborted.  Command executed:
$PSQL --quiet -U postgres -h $PG_SOCKETS 
      -c \"SELECT pg_start_backup('$PITR_BASEBACKUP_ID');\" 
      -P tuples_only -P format=unaligned

Logfile:
$PITR_BASEBACKUP_LOG

$BACKUP_LOG_ERROR_MESSAGE_BOTTOM
-------------------------------------------------------------------------"

	sendmail "$message" "[ERROR: ${SERVICE_HOSTNAME}] - pg_start_backup() returns an error"

	TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`

	echo -e "${TIMESTAMP} [ERROR] pg_start_backup() returns an error" >> $PITR_BASEBACKUP_LOG
	exit 1
    fi
}


# ########################################
# ########################################
# Function stop_backup()
#
# Runs "SELECT pg_stop_backup();"
# to register that a basebackup is finish.
#
# We try to run this command if a basebackup finnish
# with an error or crash.
#
# Script is aborted if this command returns an error
#
# ########################################
# ########################################

stop_backup(){

    if WAL_ID_STOP=`$PSQL --quiet -U postgres -h $PG_SOCKETS -c "SELECT pg_xlogfile_name(pg_stop_backup());" -P tuples_only -P format=unaligned  2>> $PITR_BASEBACKUP_LOG`
    then
        TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
        echo -e "${TIMESTAMP} [OK] Backup process stopped" >> $PITR_BASEBACKUP_LOG
	OUTPUT=${OUTPUT}"${TIMESTAMP} [OK] Backup process stopped
"                                
	
	TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
	echo -e "${TIMESTAMP} [OK] Last WAL file that needs to be archived during the PITR basebackup: ${WAL_ID_STOP}" >> $PITR_BASEBACKUP_LOG
	OUTPUT=${OUTPUT}"${TIMESTAMP} [OK] Last WAL file that needs to be archived during the PITR basebackup: ${WAL_ID_STOP}
"
    else
	message="
-------------------------------------------------------------------------
Host: $HOSTNAME_LONG
Service host / SG package: $SERVICE_HOSTNAME
Date: $DATE_TIME
-------------------------------------------------------------------------

ERROR:  pg_stop_backup() returns an error.

This should not happen. Command executed:
$PSQL --quiet -U postgres -h $PG_SOCKETS 
      -c \"SELECT pg_stop_backup();\" -P tuples_only 
      -P format=unaligned

PITR base backup aborted.

Logfile:
$PITR_BASEBACKUP_LOG

$BACKUP_LOG_ERROR_MESSAGE_BOTTOM
-------------------------------------------------------------------------"

	sendmail "$message" "[ERROR: ${SERVICE_HOSTNAME}] - pg_stop_backup() returns an error"
	
	TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
	
	echo -e "${TIMESTAMP} [ERROR] pg_stop_backup() returns an error" >> $PITR_BASEBACKUP_LOG
	
	exit 1
    fi
}

# ########################################
# ########################################
# Function base_backup()
#
# It creates a basebackup:
#
# - Creates a snapshot of $DEV_DATA_PARTITION (data)
# - Mounts the snapshot under $PG_BACKUP_PITR_SNAPSHOT
# - Generates a tar.bz file of all files under $PG_BACKUP_PITR_SNAPSHOT
# - Umount $PG_BACKUP_PITR_SNAPSHOT
# - Remove the snapshot of $DEV_DATA_PARTITION
#
# Script is aborted if something returns an error
#
# ########################################
# ########################################

base_backup(){

    if [ $BACKUP_COMPRESSION_FORMAT = "bzip2" ]; then
	
	TAR_COMMAND="$TAR --exclude=lost+found -cjvf"
	PITR_BASEBACKUP_FILE="${PITR_BASEBACKUP_ID}.tar.bz2"
	
    elif [ $BACKUP_COMPRESSION_FORMAT = "gzip" ]; then
	
	TAR_COMMAND="$TAR --exclude=lost+found -czvf"
	PITR_BASEBACKUP_FILE="${PITR_BASEBACKUP_ID}.tar.gz"
    fi

    #
    # We find out the free space available in the VG with "PE Size x Free PE" instead of from "Free  PE / Size"
    # We asume that the PE size is given in MB.
    #
   
    let PE_SIZE=`$VGDISPLAY ${VG_NAME_DATA} | $EGREP "PE Size" | $AWK -F ' ' '{print $3}' | $AWK -F '.' '{print $1}'`
    let FREE_PE=`$VGDISPLAY ${VG_NAME_DATA} | $EGREP "Free  PE" | $AWK -F ' ' '{print $5}'`

    let FREE_DATAVG=(${PE_SIZE}*${FREE_PE})

    TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`

    echo -e "${TIMESTAMP} [OK] Free space under data VG: ${FREE_DATAVG}MB" >> $PITR_BASEBACKUP_LOG
    OUTPUT=${OUTPUT}"${TIMESTAMP} [OK] Free space under data VG: ${FREE_DATAVG}MB
"
    ## TODO - evaluate if not easier with -l100%FREE
    if $LVCREATE -L${FREE_DATAVG}MB -s -n $PITR_SNAPSHOT_NAME $DEV_DATA_PARTITION >> $PITR_BASEBACKUP_LOG 2>&1
	then
	TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`

	echo -e "${TIMESTAMP} [OK] Snapshot ${PITR_SNAPSHOT_NAME} created" >> $PITR_BASEBACKUP_LOG
	OUTPUT=${OUTPUT}"${TIMESTAMP} [OK] Snapshot ${PITR_SNAPSHOT_NAME} created
"
	if $MOUNT $DEV_PITR_SNAPSHOT_PARTITION $PG_BACKUP_PITR_SNAPSHOT >> $PITR_BASEBACKUP_LOG 2>&1
	    then
	    TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`

	    echo -e "${TIMESTAMP} [OK] LVM Snapshot mounted under $PG_BACKUP_PITR_SNAPSHOT" >> $PITR_BASEBACKUP_LOG
	    OUTPUT=${OUTPUT}"${TIMESTAMP} [OK] LVM Snapshot mounted under $PG_BACKUP_PITR_SNAPSHOT
"
	    if cd $PG_BACKUP_PITR_SNAPSHOT && $TAR_COMMAND $PITR_BASEBACKUP_FILE * >> $PITR_BASEBACKUP_LOG 2>&1 && cd / 
		then
		TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`

		echo -e "${TIMESTAMP} [OK] $PITR_BASEBACKUP_FILE file created" >> $PITR_BASEBACKUP_LOG
		OUTPUT=${OUTPUT}"${TIMESTAMP} [OK] $PITR_BASEBACKUP_FILE file created
"
		if $UMOUNT $PG_BACKUP_PITR_SNAPSHOT >> $PITR_BASEBACKUP_LOG 2>&1
		    then
		    TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`

		    echo -e "${TIMESTAMP} [OK] Snapshot partition ${PG_BACKUP_PITR_SNAPSHOT} umounted" >> $PITR_BASEBACKUP_LOG
		    OUTPUT=${OUTPUT}"${TIMESTAMP} [OK] Snapshot partition ${PG_BACKUP_PITR_SNAPSHOT} umounted
"

		    SNAPSHOT_INFORMATION=`$LVDISPLAY $DEV_PITR_SNAPSHOT_PARTITION`
		    
		    TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`

		    echo -e "${TIMESTAMP} [OK] Snapshot final information saved" >> $PITR_BASEBACKUP_LOG
		    OUTPUT=${OUTPUT}"${TIMESTAMP} [OK] Snapshot final information saved
"	    

		    if $LVREMOVE -f $DEV_PITR_SNAPSHOT_PARTITION >> $PITR_BASEBACKUP_LOG 2>&1
			then
			TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`

			echo -e "${TIMESTAMP} [OK] Snapshot LV $DEV_PITR_SNAPSHOT_PARTITION removed" >> $PITR_BASEBACKUP_LOG
			OUTPUT=${OUTPUT}"${TIMESTAMP} [OK] Snapshot LV $DEV_PITR_SNAPSHOT_PARTITION removed
"
		    else
			message="
-------------------------------------------------------------------------
Host: $HOSTNAME_LONG
Service host / SG package: $SERVICE_HOSTNAME
Date: $DATE_TIME
-------------------------------------------------------------------------

ERROR - Problems removing PITR snapshot volume. PITR base backup aborted.

Command executed:
$LVREMOVE -f $DEV_PITR_SNAPSHOT_PARTITION

Logfile:
$PITR_BASEBACKUP_LOG

$BACKUP_LOG_ERROR_MESSAGE_BOTTOM 
-------------------------------------------------------------------------"

			sendmail "$message" "[ERROR: ${SERVICE_HOSTNAME}] - Problems removing PITR snapshot volume"
					
			TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
			echo -e "${TIMESTAMP} [ERROR] Problems removing PITR snapshot volume" >> $PITR_BASEBACKUP_LOG
			
			#
                        # Trying to clean up after an error/crash situation
                        #
			
			if $REMOVE -f ${PITR_BASEBACKUP_FILE} >> $PITR_BASEBACKUP_LOG 2>&1
			then
			    TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
			    echo -e "${TIMESTAMP} [CLEANUP] ${PITR_BASEBACKUP_FILE} deleted." >> $PITR_BASEBACKUP_LOG
			else
			    TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
			    echo -e "${TIMESTAMP} [CLEANUP-ERROR] Could not delete ${PITR_BASEBACKUP_FILE}." >> $PITR_BASEBACKUP_LOG
			fi
			
			stop_backup

			exit 1
		    fi
		else
		    message="
 -------------------------------------------------------------------------
 Host: $HOSTNAME_LONG
 Service host / SG package: $SERVICE_HOSTNAME
 Date: $DATE_TIME
 -------------------------------------------------------------------------

 ERROR - Problems umonting PITR snapshot volume. PITR base backup aborted.

 Command executed:
 $UMOUNT $PG_BACKUP_PITR_SNAPSHOT

Logfile:
$PITR_BASEBACKUP_LOG

$BACKUP_LOG_ERROR_MESSAGE_BOTTOM 
-------------------------------------------------------------------------
"
		    sendmail "$message" "[ERROR: ${SERVICE_HOSTNAME}] - Problems umounting PITR snapshot volume"
		  		    
		    TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
		    echo -e "${TIMESTAMP} [ERROR] Problems umounting PITR snapshot volume" >> $PITR_BASEBACKUP_LOG
		    
		    #
                    # Trying to clean up after an error/crash situation
                    #
			
		    if $REMOVE -f ${PITR_BASEBACKUP_FILE} >> $PITR_BASEBACKUP_LOG 2>&1
		    then
			TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
			echo -e "${TIMESTAMP} [CLEANUP] ${PITR_BASEBACKUP_FILE} deleted." >> $PITR_BASEBACKUP_LOG
		    else
			TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
			echo -e "${TIMESTAMP} [CLEANUP-ERROR] Could not delete ${PITR_BASEBACKUP_FILE} ." >> $PITR_BASEBACKUP_LOG
		    fi
		    
		    stop_backup

		    exit 1
		fi
	    else
		message="
-------------------------------------------------------------------------
Host: $HOSTNAME_LONG
Service host / SG package: $SERVICE_HOSTNAME
Date: $DATE_TIME
-------------------------------------------------------------------------

ERROR - Problems creating PITR base tar.bz file. PITR base backup aborted.

Command executed:
$TAR_COMMAND $PITR_BASEBACKUP_FILE $PG_BACKUP_PITR_SNAPSHOT

Logfile:
$PITR_BASEBACKUP_LOG
		
$BACKUP_LOG_ERROR_MESSAGE_BOTTOM 
-------------------------------------------------------------------------
"
		sendmail "$message" "[ERROR: ${SERVICE_HOSTNAME}] - Problems creating PITR base tar.bz file"
		
		TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
		echo -e "${TIMESTAMP} [ERROR] Problems creating PITR base $PITR_BASEBACKUP_FILE file" >> $PITR_BASEBACKUP_LOG
		
		cd / >> $PITR_BASEBACKUP_LOG 2>&1

		#
                # Trying to clean up after an error/crash situation
                #
		
		if $REMOVE -f ${PITR_BASEBACKUP_FILE} >> $PITR_BASEBACKUP_LOG 2>&1
		then
		    TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
		    
		    echo -e "${TIMESTAMP} [CLEANUP] ${PITR_BASEBACKUP_FILE} deleted." >> $PITR_BASEBACKUP_LOG
		fi

		if $UMOUNT $PG_BACKUP_PITR_SNAPSHOT >> $PITR_BASEBACKUP_LOG 2>&1
		then
		    TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
		    
		    echo -e "${TIMESTAMP} [CLEANUP] Snapshot partition ${PG_BACKUP_PITR_SNAPSHOT} umounted" >> $PITR_BASEBACKUP_LOG
		fi
		
		if $LVREMOVE -f $DEV_PITR_SNAPSHOT_PARTITION >> $PITR_BASEBACKUP_LOG 2>&1
		then
		    TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
		    
		    echo -e "${TIMESTAMP} [CLEANUP] Snapshot LV $DEV_PITR_SNAPSHOT_PARTITION removed" >> $PITR_BASEBACKUP_LOG
		fi
		
		stop_backup
		
		exit 1
	    fi
	else
	    message="
-------------------------------------------------------------------------
Host: $HOSTNAME_LONG
Service host / SG package: $SERVICE_HOSTNAME
Date: $DATE_TIME
-------------------------------------------------------------------------

ERROR - Problems mounting PITR snapshot volume. PITR base backup aborted.

Command executed:
$MOUNT $DEV_PITR_SNAPSHOT_PARTITION $PG_BACKUP_PITR_SNAPSHOT

Logfile:
$PITR_BASEBACKUP_LOG

$BACKUP_LOG_ERROR_MESSAGE_BOTTOM 
-------------------------------------------------------------------------
"
	    
	    sendmail "$message" "[ERROR: ${SERVICE_HOSTNAME}] - Problems mounting PITR snapshot volume"
	  	    
	    TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`

	    echo -e "${TIMESTAMP} [ERROR] Problems mounting PITR snapshot volume" >> $PITR_BASEBACKUP_LOG
	    
	    cd / >> $PITR_BASEBACKUP_LOG 2>&1
	    
	    #
            # Trying to clean up after an error/crash situation
            #
	    
	    if $UMOUNT $PG_BACKUP_PITR_SNAPSHOT >> $PITR_BASEBACKUP_LOG 2>&1
	    then
		TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
		
		echo -e "${TIMESTAMP} [CLEANUP] Snapshot partition ${PG_BACKUP_PITR_SNAPSHOT} umounted" >> $PITR_BASEBACKUP_LOG
	    fi
		    
	    if $LVREMOVE -f $DEV_PITR_SNAPSHOT_PARTITION >> $PITR_BASEBACKUP_LOG 2>&1
	    then
		TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
		
		echo -e "${TIMESTAMP} [CLEANUP] Snapshot LV $DEV_PITR_SNAPSHOT_PARTITION removed" >> $PITR_BASEBACKUP_LOG
	    fi
	    
	    stop_backup
	    
	    exit 1
	fi
    else
	message="
-------------------------------------------------------------------------
Host: $HOSTNAME_LONG
Service host / SG package: $SERVICE_HOSTNAME
Date: $DATE_TIME
-------------------------------------------------------------------------

ERROR - Problems creating the snapshot volume. PITR base backup aborted.

Command executed:
$LVCREATE -L${FREE_DATAVG}MB -s -n $PITR_SNAPSHOT_NAME $DEV_DATA_PARTITION

Logfile:
$PITR_BASEBACKUP_LOG

$BACKUP_LOG_ERROR_MESSAGE_BOTTOM 
-------------------------------------------------------------------------
"
	sendmail "$message" "[ERROR: ${SERVICE_HOSTNAME}] - Problems creating the PITR snapshot volume"
	
	TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`

	echo -e "${TIMESTAMP} [ERROR] Problems creating the snapshot volume" >> $PITR_BASEBACKUP_LOG
	
	cd / >> $PITR_BASEBACKUP_LOG 2>&1

	#
        # Trying to clean up after an error/crash situation
        #

	if $UMOUNT $PG_BACKUP_PITR_SNAPSHOT >> $PITR_BASEBACKUP_LOG 2>&1
	then
	    TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
	    
	    echo -e "${TIMESTAMP} [CLEANUP] Snapshot partition ${PG_BACKUP_PITR_SNAPSHOT} umounted" >> $PITR_BASEBACKUP_LOG
	fi
		
	if $LVREMOVE -f $DEV_PITR_SNAPSHOT_PARTITION >> $PITR_BASEBACKUP_LOG 2>&1
	then
	    TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
	    
	    echo -e "${TIMESTAMP} [CLEANUP] Snapshot LV $DEV_PITR_SNAPSHOT_PARTITION removed" >> $PITR_BASEBACKUP_LOG
	fi
	
	stop_backup
	
	exit 1
    fi
}


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

    if ! $COPY $PG_ARCH_PARTITION/$LASTWAL $PG_BACKUP_PITR_LAST >> $PITR_BASEBACKUP_LOG 2>&1
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
$PITR_BASEBACKUP_LOG

$BACKUP_LOG_ERROR_MESSAGE_BOTTOM 
-------------------------------------------------------------------------
"
	
        sendmail "$message" "[WARNING: ${SERVICE_HOSTNAME}] - Could not copy last WAL"

	TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`

	echo -e "${TIMESTAMP} [WARNING] Could not copy last WAL" >> $PITR_BASEBACKUP_LOG
    else
	TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
	
	echo -e "${TIMESTAMP} [OK] Last WAL file copied from $PG_ARCH_PARTITION/$LASTWAL to $PG_BACKUP_PITR_LAST" >> $PITR_BASEBACKUP_LOG
	OUTPUT=${OUTPUT}"${TIMESTAMP} [OK] Last WAL file copied from $PG_ARCH_PARTITION/$LASTWAL to $PG_BACKUP_PITR_LAST
"
    fi
}



# ########################################
# ########################################
# Function delete_old_files()
#
# Deletes WAL files and basebackup files
# not needed anymore.
#
# ########################################
# ########################################

delete_old_files(){

    # Original code from Rajesh Kumar Mallah" <mallah ( dot ) rajesh ( at ) gmail ( dot ) com>
    # The code in this function is based on a script published at pgsql-admin@postgresql.org, Wed, 29 Mar 2006 18:15:59
    # with some modifications.
    

    #
    # Trying to clean up after an error/crash situation
    #
    
    EMPTY_FILES=`$FIND $PG_BACKUP_PITR_WAL -size 0c`

    for EMPTY_FILESID in $EMPTY_FILES ;
    do
	if $REMOVE -f $EMPTY_FILESID >> $PITR_BASEBACKUP_LOG 2>&1
	then
	    
	    TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
	    
	    echo -e "${TIMESTAMP} [CLEANUP] $EMPTY_FILESID with 0 Kb under $PG_BACKUP_PITR_WAL deleted" >> $PITR_BASEBACKUP_LOG
	    OUTPUT=${OUTPUT}"${TIMESTAMP} [CLEANUP] $EMPTY_FILESID with 0 Kb under $PG_BACKUP_PITR_WAL deleted
"
	fi
    done
    
    TO_SEARCH="${WAL_ID_STOP}" 
    
    TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`

    echo "${TIMESTAMP} [OK] Starting transaction log location: $WAL_LOCATION_START"  >> $PITR_BASEBACKUP_LOG
    echo "${TIMESTAMP} [OK] Starting transaction log WAL: $WAL_ID_START"  >> $PITR_BASEBACKUP_LOG

    echo "${TIMESTAMP} [OK] WAL file to search: $TO_SEARCH"  >> $PITR_BASEBACKUP_LOG

    OUTPUT=${OUTPUT}"${TIMESTAMP} [OK] Starting transaction log location: $WAL_LOCATION_START
"
    OUTPUT=${OUTPUT}"${TIMESTAMP} [OK] Starting transaction log WAL: $WAL_ID_START
"

    OUTPUT=${OUTPUT}"${TIMESTAMP} [OK] WAL file to search: $TO_SEARCH
"

    while true; do
        REF_FILE=`$LS -1 $PG_BACKUP_PITR_WAL | $EGREP "$TO_SEARCH" | $SORT -r | $HEAD -1`
        if [ ! "$REF_FILE" ]; then
	    
	    TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`

	    echo -e "${TIMESTAMP} [OK] Waiting for ${TO_SEARCH} under $PG_BACKUP_PITR_WAL" >> $PITR_BASEBACKUP_LOG
	    OUTPUT=${OUTPUT}"${TIMESTAMP} [OK] Waiting for ${TO_SEARCH} under $PG_BACKUP_PITR_WAL
"
	else
	    break
        fi
        sleep 3
    done
    
    REF_FILE_NUM=$WAL_ID_START
    
#
# Delete old WAL files under $PG_BACKUP_PITR_WAL
#
    
    TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
 
    echo -e "${TIMESTAMP} [OK] Removing WAL files older than ${REF_FILE_NUM}" >> $PITR_BASEBACKUP_LOG
    OUTPUT=${OUTPUT}"${TIMESTAMP} [OK] Removing WAL files older than ${REF_FILE_NUM}
"
    for id in `$LS -1 $PG_BACKUP_PITR_WAL` ;
      do
      FILE_NUM=${id:0:24}
      
        # compare if the number is less than the reference
        # here string comparison is being used.
      
      if [[ "$FILE_NUM" < "$REF_FILE_NUM" ]]
	  then
	  if $REMOVE -f $PG_BACKUP_PITR_WAL/$id >> $PITR_BASEBACKUP_LOG 2>&1
	      then
	      
	      TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`

	      echo -e "${TIMESTAMP} [OK] ${PG_BACKUP_PITR_WAL}/${id} removed" >> $PITR_BASEBACKUP_LOG
	      OUTPUT=${OUTPUT}"${TIMESTAMP} [OK] ${PG_BACKUP_PITR_WAL}/${id} removed
"
	  else
	      message="
-------------------------------------------------------------------------
Host: $HOSTNAME_LONG
Service host / SG package: $SERVICE_HOSTNAME
Date: $DATE_TIME
-------------------------------------------------------------------------

WARNING - Could not remove OLD WAL file $id under
$PG_BACKUP_PITR_WAL

Logfile:
$PITR_BASEBACKUP_LOG

$BACKUP_LOG_ERROR_MESSAGE_BOTTOM 
-------------------------------------------------------------------------
"
	      sendmail "$message" "[WARNING: ${SERVICE_HOSTNAME}] - Could not remove OLD WAL file $id"
	    	      
	      TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
	      
	      echo -e "${TIMESTAMP} [WARNING] Could not remove OLD WAL file ${PG_BACKUP_PITR_WAL}/${id}" >> $PITR_BASEBACKUP_LOG
	      OUTPUT=${OUTPUT}"${TIMESTAMP} [WARNING] Could not remove OLD WAL file ${PG_BACKUP_PITR_WAL}/${id}
"
	  fi
      fi
    done
    
#
# Delete old WAL files under $PG_BACKUP_PITR_LAST
#
    
    for id in `$LS -1 $PG_BACKUP_PITR_LAST` ;
      do
      FILE_NUM=${id:0:24}
      
        # compare if the number is less than the reference
        # here string comparison is being used.
      if [[ $FILE_NUM  < $LASTWAL ]]
          then
	  if $REMOVE -f $PG_BACKUP_PITR_LAST/$id >> $PITR_BASEBACKUP_LOG 2>&1
	      then
	      TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
	      
	      echo -e "${TIMESTAMP} [OK] ${PG_BACKUP_PITR_LAST}/${id} removed" >> $PITR_BASEBACKUP_LOG
	      OUTPUT=${OUTPUT}"${TIMESTAMP} [OK] ${PG_BACKUP_PITR_LAST}/${id} removed
"
	  else
	      message="
-------------------------------------------------------------------------
Host: $HOSTNAME_LONG
Service host / SG package: $SERVICE_HOSTNAME
Date: $DATE_TIME
-------------------------------------------------------------------------

WARNING - Could not remove OLD LAST WAL file $id under
$PG_BACKUP_PITR_LAST

Logfile:
$PITR_BASEBACKUP_LOG

$BACKUP_LOG_ERROR_MESSAGE_BOTTOM 
-------------------------------------------------------------------------
"
	      
	      sendmail "$message" "[WARNING: ${SERVICE_HOSTNAME}] - Could not remove OLD LAST WAL file $id"
	    	      
	      TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`

	      echo -e "${TIMESTAMP} [WARNING] Could not remove OLD LAST WAL file ${PG_BACKUP_PITR_LAST}/${id}" >> $PITR_BASEBACKUP_LOG
	      OUTPUT=${OUTPUT}"${TIMESTAMP} [WARNING] Could not remove OLD LAST WAL file ${PG_BACKUP_PITR_LAST}/${id}
"
	  fi
      fi
    done

#
# Delete old PITR base backup files under 
#
    
    if $FIND $PG_BACKUP_PITR_DATA/ \! -newer $PITR_BASEBACKUP_FILE -type f | $EGREP -v "^$PITR_BASEBACKUP_FILE$" | $XARGS $REMOVE -f >> $PITR_BASEBACKUP_LOG 2>&1
	then
	TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
	
	echo -e "${TIMESTAMP} [OK] OLD PITR base backup files removed" >> $PITR_BASEBACKUP_LOG
	OUTPUT=${OUTPUT}"${TIMESTAMP} [OK] OLD PITR base backup files removed
"
    else
	message="
-------------------------------------------------------------------------
Host: $HOSTNAME_LONG
Service host / SG package: $SERVICE_HOSTNAME
Date: $DATE_TIME
-------------------------------------------------------------------------

WARNING - Could not remove OLD PITR base files under
$PG_BACKUP_PITR_DATA

Logfile:
$PITR_BASEBACKUP_LOG

$BACKUP_LOG_ERROR_MESSAGE_BOTTOM 
-------------------------------------------------------------------------
"
	sendmail "$message" "[WARNING: ${SERVICE_HOSTNAME}] - Could not remove OLD PITR base files"
	
	TIMESTAMP=`$DATE_ "+[%Y-%m-%d %H:%M:%S]"`
	
	echo -e "${TIMESTAMP} [WARNING] Could not remove OLD PITR base files" >> $PITR_BASEBACKUP_LOG
	OUTPUT=${OUTPUT}"${TIMESTAMP} [WARNING] Could not remove OLD PITR base files
"
    fi
}


# ########################################
# ########################################
# Function backup_ok()
#
# Updates 'pgadmin' database and sends 
# an e-post with information
#
# ########################################
# ########################################

backup_ok(){
    let PITRBASE_SIZE=`$STAT -c %s $PITR_BASEBACKUP_FILE`/1024/1024
  
    message="
-------------------------------------------------------------------------
Host: $HOSTNAME_LONG
Service host / SG package: $SERVICE_HOSTNAME
Date: $DATE_TIME
-------------------------------------------------------------------------

PITR base backup done.

Base backup: 
$PITR_BASEBACKUP_FILE

WALs archived under: 
$PG_BACKUP_PITR_WAL

Last WAL archived under: 
$PG_BACKUP_PITR_LAST

Base backup size: $PITRBASE_SIZE MB

Logfile:
$PITR_BASEBACKUP_LOG

Logfile retention period:
$PITR_BACKUP_LOG_RETENTION

PITR process output:
$OUTPUT

PITR snapshot final information:

$SNAPSHOT_INFORMATION

-------------------------------------------------------------------------
"
    
    sendmail "$message" "[OK: ${SERVICE_HOSTNAME}] - PITR base backup done"
}    


# ########################################
# ########################################
# M A I N
# ########################################
# ########################################

help(){
       
    echo
    echo "Script: $0" 
    echo "Version: ${VERSION}"
    
    echo "
Description: This script is used to create a base backup of PGDATA
             that can be used by PITR to restore the database."

    echo
    echo "Usage: "
    echo "       `basename $0` [-v][-h][-j jobID][-S service_hostname][-c t|f][-e t|f][-p retention period]"
    echo 
    echo "       -h Help"
    echo "       -v Version"
    echo "       -S Hostname/SG package running postgreSQL (*)"
    echo "       -p PITR backup log retention period (interval)"
    echo
    echo "       (*) - Must be defined"
    echo
    echo "Example: `basename $0` -S dbpg-example -j 6 -c t -e f "
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
while getopts "hvS:p:" Option
  do
  case $Option in
      h) 
	  help
	  exit 0;;
      
      v)
	  echo 
	  echo " Name: `basename $0`"
	  echo " Version: ${VERSION}"
	  echo " Description: PITR basebackup script"
	  echo " Contact: postgres-core@usit.uio.no"
	  echo
	  exit 0;;

      S) 
    SERVICE_HOSTNAME=$OPTARG;;

      p)
    PITR_BACKUP_LOG_RETENTION=$OPTARG;;
     
  esac
done 
shift $(($OPTIND - 1))


# ########################################
# ########################################
# Sanity check
# ########################################
# ########################################

if [ -z "$SERVICE_HOSTNAME" ] 
    then
    echo
    echo "ERROR: No service_hostname has been defined"
    echo
    help

    sendmail "ERROR: Hostname/SG package not defined" "[ERROR: $HOSTNAME_LONG] - Hostname/SG package not defined"
    exit $E_OPTERROR
fi

#
# If $PITR_BACKUP_LOG_RETENTION is not defined, use default BACKUP_DEFAULT_RETENTION_PERIOD from database
#

if [ -z "$PITR_BACKUP_LOG_RETENTION" ]; then
    PITR_BACKUP_LOG_RETENTION="$BACKUP_DEFAULT_RETENTION_PERIOD"
fi


# ########################################
# Local variables
# ########################################

OUTPUT="
"

PITR_BASEBACKUP_LOG=${PG_LOGS_PARTITION}/pitr_basebackup-${SERVICE_HOSTNAME}_v${PGVERSION}_${FILE_ID}.log
PITR_BASEBACKUP_ID=${PG_BACKUP_PITR_DATA}/PITRBASE-${SERVICE_HOSTNAME}_v${PGVERSION}_${FILE_ID}


check_partitions
check_basebackup_file

start_backup
base_backup
last_wal
stop_backup

delete_old_files
backup_ok

exit 0;

#
# EOF
#