## Настройка сервера Web

На сервере поднимаем nginx, настраиваем сайт site.project. 
Когфиг nginx для сайта - /etc/nginx/conf.d/site.project.conf

Файлы сайта лежат в каталоге /var/www/site.project

Отправка логов на центральный сервер производится через jornald, для мониторинга
используется модуль node_exporter.

Для бэкапа используется borgbackup, резервное копирование производится на сервер Backup.
Для создания ssh соединения между клиентом (project-web) и сервером (project-backup) используются заранее сгенерированные ключи (для упрощения).
Также для упрощения работа производится от пользователя root на клиенте и сервере.

В плейбук project.yml для настройки сервера после поднятия исполльзуется роль web. Далее идет описание  
файла task/main.yml.  

---

    # tasks file for web

Настраиваем /etc/hosts

    - name: WEB SERVER | CHANGE HOSTS FILE
      lineinfile: 
        path: /etc/hosts
        line: 192.168.100.4 project-mysql
        state: present
        
Устанавливаем необходимые пакеты        

    - name: WEB SERVER | INSTALL PACKAGES
      yum:
        name:
          - nginx
          - php-fpm
          - php-mysqlnd
          - php-cli
          - php-json
          - php-gd
          - php-ldap
          - php-odbc
          - php-pdo
          - php-opcache
          - php-pear 
          - php-xml 
          - php-xmlrpc 
          - php-mbstring 
          - php-snmp 
          - php-soap 
          - php-zip
          - policycoreutils-python-utils
          - setools-console
          - setroubleshoot-server
          - systemd-journal-gateway
        state: present
        
Запускаем nginx

    - name: WEB SERVER | START NGINX
      systemd:
        name: nginx
        state: started
        enabled: yes
        
настраиваем firewalld        
    
    - name: WEB SERVER | CONFIG FIREWALLD FOR HTTP HTTPS
      shell: firewall-cmd --permanent --zone=public --add-service=http ; firewall-cmd --permanent --zone=public --add-service=https ; firewall-cmd --reload
  
Создаем директории для сайта

    - name: WEB SERVER | CREATE HTTML DIR FOR SITE     
      file:
        path: /var/www/site.project/html
        state: directory
        recurse: yes
        group: vagrant
        owner: vagrant 
        
    - name: WEB SERVER | CREATE LOGS DIR FOR SITE     
      file:
        path: /var/www/site.project/logs
        state: directory
        recurse: yes
        group: vagrant
        owner: vagrant
    
    - name: WEB SERVER | CREATE ACCESS.LOG FOR SITE
      file:
        path: /var/www/site.project/logs/access.log
        state: touch
        group: vagrant
        owner: vagrant
    
    - name: WEB SERVER | CREATE ERROR.LOG FOR SITE
      file:
        path: /var/www/site.project/logs/error.log
        state: touch
        group: vagrant
        owner: vagrant 
    
Настраиваем и копируем ssl-cертификаты для сайта

    - name: WEB SERVER | CREATE SSL CERTS DIR FOR SITE
      file:
        path: /var/www/site.project/certs
        state: directory
        recurse: yes
        group: vagrant
        owner: vagrant    
    
    - name: WEB SERVER | COPY SSL CERTS FOR SITE
      copy:
        src: '{{item}}' 
        dest: /var/www/site.project/certs/
      loop:
        - files/site.project.crt
        - files/device.key
        - files/site.project.csr
    
Копируем конфиг сайта    
    
    - name: WEB SERVER | COPY SITE NGINX CONFIG
      copy:
        src: files/site.project.conf
        dest: /etc/nginx/conf.d/
    
Настраиваем SELinux для nginx    
    
    - name: WEB SERVER | CONFIGURE SELINUX FOR NGINX
      shell: semanage fcontext -a -t httpd_sys_rw_content_t /var/www/site.project/logs/access.log ; restorecon -v /var/www/site.project/logs/access.log ; semanage fcontext -a -t httpd_sys_rw_content_t /var/www/site.project/logs/error.log ; restorecon -v /var/www/site.project/logs/error.log
    
Перезапускаем nginx

    - name: WEB SERVER | RESTART NGINX
      systemd:
        name: nginx
        state: restarted
    
 Копируем контент сайта   
      
    - name: WEB SERVER | COPY SITE CONTENT
      unarchive:
        src: files/html.tar.gz
        dest: /var/www/site.project/html
    
    - name: WEB SERVER | CHOWN DIR FOR SITE     
      shell: chown -R vagrant:vagrant /var/www/site.project  
 
настраиваем SELinux для PHP

    - name: WEB SERVER | CONFIGURE SELINUX FOR PHPНастраиваем /etc/hosts
      shell: setsebool -P httpd_can_network_connect 1 ; setsebool -P httpd_execmem 1 ; setsebool -P httpd_can_network_relay 1 ; setsebool -P nis_enabled 1 ; setsebool -P httpd_can_network_connect_db 1

Блок настройки бэкапа

    #==================== Configure backup====================================================================

Добавляем в /etc/hosts серверную машину

    - name: WEB SERVER FOR BACKUP | CHANGE HOSTS FILE
      lineinfile: 
        path: /etc/hosts
        line: 192.168.100.5 project-backup
        state: present
    
Настраиваем подключение по ssh между клиентом и сервером  
        
    - name: WEB SERVER FOR BACKUP | CREATE DIR /root/.ssh    
      file:
        path: /root/.ssh
        state: directory
       
    - name: WEB SERVER FOR BACKUP | COPY PRIVATE SSH KEY
      copy:
        src: files/id_rsa
        dest: /root/.ssh
        mode: '600'
      
    - name: WEB SERVER FOR BACKUP | COPY PUB SSH KEY 
      copy:
        src: files/id_rsa.pub
        dest: /root/.ssh
        mode: '644'
    
    - name: WEB SERVER FOR BACKUP | COPY PRIVATE SERVER KEY  
      copy:
        src: files/ssh_host_rsa_key
        dest: /etc/ssh
        mode: '640'
        
    - name: WEB SERVER FOR BACKUP | COPY PUBLIC SERVER KEY  
      copy:
        src: files/ssh_host_rsa_key.pub
        dest: /etc/ssh
        mode: '644'
        
    - name: WEB SERVER FOR BACKUP | CREATE /root/.ssh/authorized_keys  
      file:
        path: /root/.ssh/authorized_keys
        state: touch
 
    - name: WEB SERVER FOR BACKUP | CREATE /root/.ssh/known_hosts  
      file:
        path: /root/.ssh/known_hosts
        state: touch   
    
    - name: WEB SERVER FOR BACKUP | COPY THE KEYS TO FILES
      blockinfile:
        path: /root/.ssh/authorized_keys
        block: "{{ lookup('file', 'files/id_rsa_s.pub') }}"

    - name: WEB SERVER FOR BACKUP | COPY THE KEYS TO FILES
      blockinfile:
        path: /root/.ssh/known_hosts
        block: "{{ lookup('file', 'files/known_hosts_c') }}"
    
Устанавливаем на клиенте borgbackup    
  
    - name: WEB SERVER FOR BACKUP | INSTALL BORGBACKUP
      shell: wget https://github.com/borgbackup/borg/releases/download/1.1.6/borg-linux64 -O /usr/local/sbin/borg ; chmod +x /usr/local/sbin/borg
  
Копируем подготовленный заранее скрипт резервного копирования в папку /root. Описание скрипта приведено ниже.  

    - name: WEB SERVER FOR BACKUP | COPY script-backup.sh
      copy:
        src: files/script-backup.sh
        dest: /root
    
Инициализируем репозиторий для бэкапов с защитой по ключу    
        
    - name: WEB SERVER FOR BACKUP | REPOSITORY INITIALIZATION
      shell: BORG_NEW_PASSPHRASE='' /usr/local/sbin/borg init --encryption=keyfile project-backup:/var/backup/project-web-system
      args:
        executable: /bin/bash
    
Копируем подготовленные файлы юнитов для запуска скрипта бэкапа в /etc/systemd/system/    
      
    - name: WEB SERVER FOR BACKUP | COPY borgback.service
      copy:
        src: files/borgback.service
        dest: /etc/systemd/system/ 
        
    - name: WEB SERVER FOR BACKUP | COPY borgback.timer
      copy:
        src: files/borgback.timer
        dest: /etc/systemd/system/  
    
Создаем директорию для логов бэкапов

    - name: WEB SERVER FOR BACKUP | CREATE /var/log/borgback  
      file:
        path: /var/log/borgback
        state: touch 

Перезапускаем демоны, активируем и запускаем borgback.service и borgback.timer.

    - name: WEB SERVER FOR BACKUP | DAEMON RELOAD
      systemd:
        daemon-reload: yes 
        
    - name: WEB SERVER FOR BACKUP | ENABLE AND START borgback.service 
      systemd:
        name: borgback.service
        enabled: yes
        state: started
        
    - name: WEB SERVER FOR BACKUP | ENABLE borgback.timer 
      systemd:
        name: borgback.timer
        enabled: yes
        state: started 
    
Копируем ключевой файл репозитория на сервер в /root/.congig/borg/keys, чтобы работать с репозиторием на сервере    
    
    - name: WEB SERVER FOR BACKUP | COPY BORG REPOSITORY KEY TO BACKUP SERVER
      shell: scp /root/.config/borg/keys/project_backup__var_backup_project_web_system 192.168.100.5:/root/.config/borg/keys/
  
Блок для мониторинга

    #================================= Configure monitoring ===========================================
  
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

    - name: WEB SERVER FOR LOGS | ADD LOGS SERVER TO /etc/systemd/journal-upload.conf
      lineinfile: 
        path: /etc/systemd/journal-upload.conf
        line: URL=http://192.168.100.6:19532
        state: present
    
Настраиваем systemd-journal-gateway и firewalld    

    - name: WEB SERVER FOR LOGS | CONFIG FIREWALLD FOR LOGS
      shell: firewall-cmd --permanent --zone=public --add-port=19532/tcp ; firewall-cmd --reload
    
    - name: WEB SERVER FOR LOGS | ENABLE AND START systemd-journal-upload.service 
      systemd:
        name: systemd-journal-upload.service
        enabled: yes
        state: started  
        
## Листинг прилагаемых к ansible файлов

#### data/client/script-backup.sh

    #!/bin/bash  
  
Задаем имя сервера бэкапов  
  
    BORG_SERVER=project-backup  
  
Задаем тип бэкапа, в нашем случае будет system 
  
    TYPE_OF_BACKUP=system  
  
Задаем путь к репозиторию  
  
    REPOSITORY="${BORG_SERVER}:/var/backup/$(hostname)-${TYPE_OF_BACKUP}"  
  
Пишем команду для создания бэкапа 

    borg create --list -v --stats \
    $REPOSITORY::"etc-{now:%Y-%m-%d-%H-%M}" \
    /                                       \
    --exclude '/proc/*'                     \
    --exclude '/mnt/*'                      \
    --exclude '/sys/*'                      \
    --exclude '/media/*'                    \
    --exclude '/dev/*'  
    
  
Задаем интервалы хранения бэкапов  
  
    #Prune old backup

    borg prune -v --list \
    --keep-within=7d \
    --keep-weekly=4 \
    $REPOSITORY    
    

#### data/client/borgback.service

    [Unit]
    Description=BorgBackup Script

    [Service]
    ExecStart=/bin/bash /root/script-backup.sh
    StandardOutput=append:/var/log/borgback
    StandardError=append:/var/log/borgback

    [Install]
    WantedBy=multi-user.target

#### data/client/borgback.timer

    [Unit]  
    Description=Timer For BorgBack service  
  
    [Timer]  
    OnUnitActiveSec=15m  
  
    [Install]  
    WantedBy=multi-user.target  

#### data/server/var-backup.mount

    [Unit]  
    Description=var-backup mount  
  
    [Mount]  
    What=/dev/sdb  
    Where=/var/backup  
    Type=ext4  
    Options=defaults  
  
    [Install]  
    WantedBy=multi-user.target  


#### Проверяем создание бэкапов. На web запускаем:
  
     borg list project-backup:/var/backup/project-web-system 
  
#### Смотрим логи бэкапов:  
 
     cat/var/log/borgback   
