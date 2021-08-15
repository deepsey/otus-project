#!/bin/bash

rm -rf /root/backupdb/*
   
DATA=`date +%Y-%m-%d`

mkdir -p /root/backupdb/$DATA

xtrabackup --backup --user=root --password='Gungland@777' --target-dir=/root/backupdb/$DATA/full
xtrabackup --prepare --user=root --password='Gungland@777' --target-dir=/root/backupdb/$DATA/full

scp -r /root/backupdb/$DATA/ project-backup:/var/backup/mysql
