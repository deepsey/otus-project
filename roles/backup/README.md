## Настройка сервера Backup

На сервере создается отдельный раздел с примонтированным диском - /var/backup.
В этой папке создается репозиторий borgbackup для корпирования с сервера web,
и папка mysql для создания резервных копий mysql.

В плейбук project.yml для настройки сервера после поднятия используется роль backup. Далее идет описание  
файла task/main.yml. 

---

    # tasks file for backup

Добавляем в /etc/hosts клиентские машины

    - name: BACKUP SERVER | CHANGE HOSTS FILE  
      blockinfile:
        path: /etc/hosts
        block: |
          192.168.100.3 project-web
          192.168.100.4 project-mysql
        state: present 
    
Настраиваем подключение по ssh между сервером и клиентами

    - name: BACKUP SERVER | CREATE DIR /root/.ssh    
      file:
        path: /root/.ssh
        state: directory
       
    - name: BACKUP SERVER | COPY PRIVATE SSH KEY
      copy:
        src: files/id_rsa
        dest: /root/.ssh
        mode: '600'
      
    - name: BACKUP SERVER | COPY PUB SSH KEY 
      copy:
        src: files/id_rsa.pub
        dest: /root/.ssh
        mode: '644'
    
    - name: BACKUP SERVER | COPY PRIVATE SERVER KEY 
      copy:
        src: files/ssh_host_rsa_key
        dest: /etc/ssh
        mode: '640'
        
    - name: BACKUP SERVER | COPY PUBLIC SERVER KEY   
      copy:
        src: files/ssh_host_rsa_key.pub
        dest: /etc/ssh
        mode: '644'
        
    - name: BACKUP SERVER | CREATE /root/.ssh/authorized_keys  
      file:
        path: /root/.ssh/authorized_keys
        state: touch
   
    - name: BACKUP SERVER | CREATE /root/.ssh/known_hosts  
      file:
        path: /root/.ssh/known_hosts
        state: touch   
    
    - name: BACKUP SERVER | COPY THE KEYS TO FILES
      blockinfile:
        path: /root/.ssh/authorized_keys
        block: "{{ lookup('file', 'files/id_rsa_c.pub') }}"
  
    - name: BACKUP SERVER | COPY THE KEYS TO FILES
      blockinfile:
        path: /root/.ssh/known_hosts
        block: "{{ lookup('file', 'files/known_hosts_s') }}"    
    
Устанавливаем на сервере borgbackup

    - name: BACKUP SERVER | INSTALL BORGBACKUP
      shell: wget https://github.com/borgbackup/borg/releases/download/1.1.6/borg-linux64 -O /usr/local/sbin/borg ; chmod +x /usr/local/sbin/borg
  
Создаем директорию для создания бэкапов    
        
    - name: BACKUP SERVER | CREATE DIR /var/backup   
      file:
        path: /var/backup
        state: directory 
    
 Создаем файловую систему на диске для бэкапов    
        
    - name: BACKUP SERVER | MAKE FS ON /dev/sdb
      filesystem:
        dev: /dev/sdb
        fstype: ext4

Копируем подготовленный файл юнита монтирования диска для бэкапов в /etc/systemd/system/  

    - name: BACKUP SERVER | COPY var-backup.mount
      copy:
        src: files/var-backup.mount
        dest: /etc/systemd/system/
    
Перезапускаем демоны, активируем и запускаем var-backup.mount     
        
    - name: BACKUP SERVER | DAEMON RELOAD
      systemd:
        daemon-reload: yes
        
    - name: BACKUP SERVER | START AND ENABLE var-backup.mount 
      systemd:
        name: var-backup.mount
        enabled: yes
        state: started
    
Создаем директорию для файла ключа репозитория    
    
    - name: BACKUP SERVER | CREATE DIR /root/.config/borg/keys   
      file:
        path: /root/.config/borg/keys
        state: directory  
    
Создаем директорию для бэкапов mysql    
    
    - name: BACKUP SERVER | CREATE DIR FOR MYSQL BACKUP /var/backup/mysql   
      file:
        path: /var/backup/mysql
        state: directory 

Блок для мониторинга

    #================================= Configure monitoring ==============================================

Устанавливаем node_exporter

    - name: BACKUP SERVER FOR MONITORING | INSTALL PROMETHEUS NODE_EXPORTER 
      yum:
        name: golang-github-prometheus-node-exporter
        state: present 
    
 Настраиваем firewalld   
    
    - name: BACKUP SERVER FOR MONITORING | CONFIG FIREWALLD FOR NODE_EXPORTER
      shell: firewall-cmd --permanent --zone=public --add-port=9100/tcp ; firewall-cmd --reload
  
Активируем и запускаем node_exporter

    - name: BACKUP SERVER FOR MONITORING | START NODE_EXPORTER
      systemd:
        name: node_exporter
        state: started
        enabled: yes   
    
Блок для передачи логов на центральный сервер

    #================================ Configure logs ===================================================    

Устанавливаем необходимые пакеты
    
    - name: BACKUP SERVER FOR LOGS | INSTALL PACKAGES
      yum:
        name: 
          - systemd-journal-gateway
          - setools-console
          - setroubleshoot-server
          - systemd-journal-gateway
        state: present
    
Настраиваем systemd-journal-gateway и firewalld    
  
    - name: BACKUP SERVER FOR LOGS | ADD LOGS SERVER TO /etc/systemd/journal-upload.conf
      lineinfile: 
        path: /etc/systemd/journal-upload.conf
        line: URL=http://192.168.100.6:19532
        state: present

    - name: BACKUP SERVER FOR LOGS | CONFIG FIREWALLD FOR LOGS
      shell: firewall-cmd --permanent --zone=public --add-port=19532/tcp ; firewall-cmd --reload
  
настраиваем SELinux для systemd-journal-gateway
  
    - name: BACKUP SERVER FOR LOGS | CONFIGURE SELINUX FOR JOURNAL-REMOTE
      shell: semanage port -a -t dns_port_t -p tcp 19532 

Активируем и запускаем systemd-journal-gateway
  
    - name: BACKUP SERVER FOR LOGS | ENABLE AND START systemd-journal-upload.service 
      systemd:
        name: systemd-journal-upload.service
        enabled: yes
        state: started       

