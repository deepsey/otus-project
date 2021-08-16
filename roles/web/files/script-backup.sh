#!/bin/bash

#Server name

BORG_SERVER=project-backup

# Backup type, it may be data, system, mysql, binlogs, etc.

TYPE_OF_BACKUP=system

REPOSITORY="${BORG_SERVER}:/var/backup/$(hostname)-${TYPE_OF_BACKUP}"

#Create backup

borg create --list -v --stats \
 $REPOSITORY::"system-{now:%Y-%m-%d-%H-%M}" \
 /                                       \
 --exclude '/proc/*'                     \
 --exclude '/mnt/*'                      \
 --exclude '/sys/*'                      \
 --exclude '/media/*'                    \
 --exclude '/dev/*' 
 
 

 
#Prune old backup

borg prune -v --list \
    --keep-within=7d \
    --keep-weekly=4 \
    $REPOSITORY
