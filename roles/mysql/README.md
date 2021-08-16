## Настройка сервера mysql

На сервере mysql поднимается БД Percona MySQL, в которую записывается контент сайта site.project.
Для бэкапов используются два скрипта, запускающие xtrabackup:

Для полного бэкапа:

#### full-backup.sh

    #!/bin/bash

    rm -rf /root/backupdb/*
   
    DATA=`date +%Y-%m-%d`

    mkdir -p /root/backupdb/$DATA

    xtrabackup --backup --user=root --password='Gungland@777' --target-dir=/root/backupdb/$DATA/full
    xtrabackup --prepare --user=root --password='Gungland@777' --target-dir=/root/backupdb/$DATA/full

    scp -r /root/backupdb/$DATA/ project-backup:/var/backup/mysql
    
Для икрементного бэкапа

#### inc-backup.sh

    #!/bin/bash
   
    DATA1=`date +%Y-%m-%d`
    DATA2=`date +%H-%M-%S`

    xtrabackup --backup --user=root --password='Gungland@777' --target-dir=/root/backupdb/$DATA1/inc-$DATA2 --incremental-basedir=/root/backupdb/$DATA1/full

    xtrabackup --prepare --user=root --password='Gungland@777' --target-dir=/root/backupdb/$DATA1/inc-$DATA2 --incremental-basedir=/root/backupdb/$DATA1/full


    scp -r /root/backupdb/$DATA1/inc-$DATA2 project-backup:/var/backup/mysql/$DATA1


Бэкапы создаются в папке /root, затем копируюся на сервер Backup в папку /var/backup/mysql

также на сервере настроены передача логов и метрик на сервер Monitoring.

### Описание провижининга сервера tasks/main.yml


