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

Также на сервере настроены передача логов и метрик на сервер Monitoring.

### Описание провижининга сервера tasks/main.yml

---

    # tasks file for mysql

Загружаем и устанавливаем пакеты

    - name: MYSQL SERVER | DOWNLOAD PERCONA MYSQL
      yum:
        name: https://repo.percona.com/yum/percona-release-latest.noarch.rpm
        state: present
        
    - name: MYSQL SERVER | INSTALL PERCONA MYSQL+XTRABACKUP
      yum:
        name: 
          - Percona-Server-server-57
          - percona-xtrabackup-24
        state: present
        
Запускаем mysql
        
    - name: MYSQL SERVER | START MYSQL
      systemd:
        name: mysql
        state: started
        enabled: yes  
        
Получаем временный пароль root mysql        
    
    - name: MYSQL SERVER | GATHER MYSQL ROOT LOGIN PASSWORD
      shell: cat /var/log/mysqld.log | grep 'root@localhost:' | awk '{print $11}'
      register: tmp_root_passwd
      ignore_errors: true
      
Изменяем пароль root mysql      
       
    - name: MYSQL SERVER | CHANGE MYSQL ROOT PASSWORD
      shell: mysql -e "SET PASSWORD = PASSWORD('{{ mysql_root_password }}');" --connect-expired-password -uroot -p"{{ tmp_root_passwd.stdout }}"   
      
Создаем базу данных wordpress      
  
    - name: MYSQL SERVER | CREATE DATABASE 
      shell: mysql -e "CREATE DATABASE {{ database_name }};" -uroot -p{{ mysql_root_password }}
      
Подключаем epel repo      
  
    - name: MYSQL SERVER | INSTALL EPEL REPO PACKAGE FROM STANDARD REPO
      yum:
        name: epel-release
        state: present
        
Устанавливаем дополнение mysql для ansible        

    - name: MYSQL SERVER | INSTALL PY-MYSQL MODULE FROM EPEL REPO
      yum:
        name: python2-PyMySQL
        state: present  
        
Создаем пользователя БД

    - name: MYSQL SERVER | CREATE DATABASE USER
      community.mysql.mysql_user:
        login_user: root
        login_password: '{{ mysql_root_password }}' 
        name: '{{ database_user }}'
        password: '{{ database_user_password }}'
        host: '%' 
        priv: '{{ database_name }}.*:ALL'
        state: present   
        
Разрешаем удаленные подключения к mysql        

    - name: MYSQL SERVER | PERMIT OUTWARD CONNECTIONS TO SERVER
      lineinfile: 
        path: /etc/my.cnf
        insertafter: '# instructions in http://fedoraproject.org/wiki/Systemd'
        line: bind-address = 0.0.0.0
        state: present
        
Перезапускаем mysql        
    
    - name: MYSQL SERVER | RESTART MYSQL
      systemd:
        name: mysql
        state: restarted
        enabled: yes 
        
Восстанавливаем базу данных из дампа        
    
    - name: MYSQL SERVER | COPY DUMP WORDPRESS
      copy:
        src: files/wordpress.sql
        dest: /root
        force: yes    
         
    - name: MYSQL SERVER | RESTORE DUMP WORDPRESS
      shell: mysql -uroot -p{{ mysql_root_password }} {{ database_name }} < /root/wordpress.sql   
  
Запускаем firewalld и кофигурируем его, разрешая порт mysql  
  
    - name: MYSQL SERVER | START FIREWALLD
      systemd:
        name: firewalld
        state: started
        enabled: yes    
        
    - name: MYSQL SERVER | CONFIG FIREWALLD FOR MYSQL    
      shell: firewall-cmd --permanent --zone=public --add-port=3306/tcp ; firewall-cmd --reload  
      
 Блок для мониторинга     

    #================================= Configure monitoring ==============================================
    
  Устанавливаем node_exporter  
  
    - name: MYSQL SERVER FOR MONITORING | INSTALL PROMETHEUS NODE_EXPORTER 
      yum:
        name: golang-github-prometheus-node-exporter
        state: present 
        
  Настраиваем firewalld      
    
    - name: MYSQL SERVER FOR MONITORING | CONFIG FIREWALLD FOR NODE_EXPORTER
      shell: firewall-cmd --permanent --zone=public --add-port=9100/tcp ; firewall-cmd --reload
      
      
  Активируем и запускаем node_exporter
  
    - name: MYSQL SERVER FOR MONITORING | START NODE_EXPORTER
      systemd:
        name: node_exporter
        state: started
        enabled: yes   


Блок для передачи логов на центральный сервер

    #================================ Configure logs ===================================================    
 
Устанавливаем необходимые пакеты 

    - name: MYSQL SERVER FOR LOGS | INSTALL PACKAGES
      yum:
        name: 
          - systemd-journal-gateway
          - setools-console
          - setroubleshoot-server
          - systemd-journal-gateway
        state: present
        
Настраиваем systemd-journal-gateway и firewall        
 
    - name: MYSQL SERVER FOR LOGS | ADD LOGS SERVER TO /etc/systemd/journal-upload.conf
      lineinfile: 
        path: /etc/systemd/journal-upload.conf
        line: URL=http://192.168.100.6:19532
        state: present
        
    - name: MYSQL SERVER FOR LOGS | CONFIG FIREWALLD FOR LOGS
      shell: firewall-cmd --permanent --zone=public --add-port=19532/tcp ; firewall-cmd --reload
      
 Настраиваем SELinux для корректной работы передачи логов     
  
    - name: MYSQL SERVER FOR LOGS | CONFIGURE SELINUX FOR JOURNAL-REMOTE
      shell: semanage port -a -t dns_port_t -p tcp 19532    
      
Запускаем systemd-journal-upload.service      
  
    - name: MYSQL SERVER FOR LOGS | ENABLE AND START systemd-journal-upload.service 
      systemd:
        name: systemd-journal-upload.service
        enabled: yes
        state: started 

Блок создания бэкапов mysql

    # =================== Configure backup====================================================================

Прописываем сервер Backup в /etc/hosts

    - name: MYSQL SERVER FOR BACKUP | CHANGE HOSTS FILE
      lineinfile: 
        path: /etc/hosts
        line: 192.168.100.5 project-backup
        state: present
        
Устанавливаем ssh ключи и настраиваем ssh соединение с сервером Backup       
        
    - name: MYSQL SERVER FOR BACKUP | CREATE DIR /root/.ssh    
      file:
        path: /root/.ssh
        state: directory
        
    - name: MYSQL SERVER FOR BACKUP | COPY PRIVATE SSH KEY
      copy:
        src: files/id_rsa
        dest: /root/.ssh
        mode: '600'
      
    - name: MYSQL SERVER FOR BACKUP | COPY PUB SSH KEY 
      copy:
        src: files/id_rsa.pub
        dest: /root/.ssh
        mode: '644'
    
    - name: MYSQL SERVER FOR BACKUP | COPY PRIVATE SERVER KEY  
      copy:
        src: files/ssh_host_rsa_key
        dest: /etc/ssh
        mode: '640'
        
    - name: MYSQL SERVER FOR BACKUP | COPY PUBLIC SERVER KEY  
      copy:
        src: files/ssh_host_rsa_key.pub
        dest: /etc/ssh
        mode: '644'
        
    - name: MYSQL SERVER FOR BACKUP | CREATE /root/.ssh/authorized_keys  
      file:
        path: /root/.ssh/authorized_keys
        state: touch
        
    - name: MYSQL SERVER FOR BACKUP | CREATE /root/.ssh/known_hosts  
      file:
        path: /root/.ssh/known_hosts
        state: touch   
        
    - name: MYSQL SERVER FOR BACKUP | COPY THE KEYS TO FILES
      blockinfile:
        path: /root/.ssh/authorized_keys
        block: "{{ lookup('file', 'files/id_rsa_s.pub') }}"
        
    - name: MYSQL SERVER FOR BACKUP | COPY THE KEYS TO FILES
      blockinfile:
        path: /root/.ssh/known_hosts
        block: "{{ lookup('file', 'files/known_hosts_c') }}"
        
 Копируем на сервер скрипты бэкапов                  
        
    - name: MYSQL SERVER FOR BACKUP | COPY full-backup.sh
      copy:
        src: files/full-backup.sh
        dest: /root
        
    - name: MYSQL SERVER FOR BACKUP | COPY inc-backup.sh
      copy:
        src: files/inc-backup.sh
        dest: /root    
        
Копируем и настраиваем systemd юниты для запуска бэкапов mysql, перезагружаем демоны        
        
    - name: MYSQL SERVER FOR BACKUP | COPY fullbackup.service        
      copy:
        src: files/fullbackup.service
        dest: /etc/systemd/system/ 
        
    - name: MYSQL SERVER FOR BACKUP | COPY fullbackup.timer
      copy:
        src: files/fullbackup.timer
        dest: /etc/systemd/system/     
        
     - name: MYSQL SERVER FOR BACKUP | COPY incbackup.service
      copy:
        src: files/incbackup.service
        dest: /etc/systemd/system/ 
        
     - name: MYSQL SERVER FOR BACKUP | COPY incbackup.timer
      copy:
        src: files/incbackup.timer
        dest: /etc/systemd/system/     
        
     - name: MYSQL SERVER FOR BACKUP | DAEMON RELOAD
      systemd:
        daemon-reload: yes 
        
 Активируем и запускаем сервисы       
        
    - name: MYSQL SERVER FOR BACKUP | ENABLE AND START fullbackup.service 
      systemd:
        name: fullbackup.service
        enabled: yes
        state: started
        
        
        
    - name: MYSQL SERVER FOR BACKUP | ENABLE fullbackup.timer 
      systemd:
        name: fullbackup.timer
        enabled: yes
        state: started 
        
        
    
    - name: MYSQL SERVER FOR BACKUP | ENABLE AND START incbackup.service 
      systemd:
        name: incbackup.service
        enabled: yes
        state: started
        
        
        
    - name: MYSQL SERVER FOR BACKUP | ENABLE incbackup.timer 
      systemd:
        name: incbackup.timer
        enabled: yes
        state: started    


## Файлы сервисов systemd
#### fullbackup.service

    [Unit]
    Description=MySQL Full Backup Script
    After=mysqld.service

    [Service]
    ExecStart=/bin/bash /root/full-backup.sh

    [Install]
    WantedBy=multi-user.target
    
#### fullbackup.timer

    [Unit]
    Description=Timer For MySQL Full Backup service

    [Timer]
    OnCalendar=*-*-* 00:00:00

    [Install]
    WantedBy=multi-user.target
    
#### incbackup.service

    [Unit]
    Description=MySQL Incremental Backup Script

    [Service]
    ExecStart=/bin/bash /root/inc-backup.sh

    [Install]
    WantedBy=multi-user.target
    
#### incbackup.timer

    [Unit]
    Description=Timer For MySQL Incremental Backup service

    [Timer]
    OnUnitActiveSec=1h

    [Install]
    WantedBy=multi-user.target


