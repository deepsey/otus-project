#!/bin/bash
   
DATA1=`date +%Y-%m-%d`
DATA2=`date +%H-%M-%S`

xtrabackup --backup --user=root --password='Gungland@777' --target-dir=/root/backupdb/$DATA1/inc-$DATA2 --incremental-basedir=/root/backupdb/$DATA1/full

xtrabackup --prepare --user=root --password='Gungland@777' --target-dir=/root/backupdb/$DATA1/inc-$DATA2 --incremental-basedir=/root/backupdb/$DATA1/full


scp -r /root/backupdb/$DATA1/inc-$DATA2 project-backup:/var/backup/mysql/$DATA1

