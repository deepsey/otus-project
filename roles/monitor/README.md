## Настройка сервера monitor

#### 1. Для построения системы централизованного хранения логов будем использовать journald.

Устанавливаем пакет systemd-journal-gateway  
Настраиваем пассивный режим работы демона systemd-journal-remote  
На удаленных серверах устанавливаем пакет systemd-journal-gateway и прописываем в него адрес центрального сервера. 
После настройки и запуска сервисов проверяем содержимое директории на центральном сервере  

    # ls /var/log/journal/remote  
    
#### 2. Для мониторинга устанавливаем prometheus и grafana, на клиентах устанавливаем node_exporter для отдачи метрик.
После установки и настройки открываем адрес сервера на порту 3000. Страницу открываем через адрес сервера Bastion.

#### 3. Краткое описание настройки сервера через роль ansible tasks/main.yml.

    # tasks file for monitor
    
Блок настройки сервера мониторинга

    #=========================== MONITORING SERVER ============================================================
    
Прописываем сервера для мониторинга в файлу /ets/hosts    

    - name: MONITOR SERVER | CHANGE HOSTS FILE
      blockinfile:
        path: /etc/hosts
        block: |
          192.168.100.2 project-bastion
          192.168.100.3 project-web
          192.168.100.4 project-mysql
          192.168.100.5 project-backup
        state: present
       
Устанавливаем пакеты prometheus И grafana

    - name: MONITOR SERVER | INSTALL PROMETHEUS+GRAFANA PACKAGES 
      yum:
        name:
          - golang-github-prometheus-node-exporter
          - golang-github-prometheus
          - grafana
          - systemd-journal-gateway
          - policycoreutils-python-utils
          - setools-console
          - setroubleshoot-server
        state: present
 
Копируем заранее подготовленный конфиг prometheus

    - name: MONITOR SERVER | COPY PROMETHEUS CONFIG
      copy:
        src: files/prometheus.yml
        dest: /etc/prometheus/
        force: yes
    
Создаем юнит prometheus

    - name: MONITOR SERVER | COPY PROMETHEUS UNIT
      copy:
        src: files/prometheus.service
        dest: /etc/systemd/system/
        force: yes 

Перезагружаем демоны systemd
    
    - name: MONITOR SERVER | DAEMON RELOAD
      systemd:
        daemon-reload: yes 
        
Настраиваем firewalld для prometheus        
    
    - name: MONITOR SERVER | CONFIG FIREWALLD FOR PROMETHEUS
      shell: firewall-cmd --permanent --zone=public --add-port=9100/tcp ; firewall-cmd --permanent --zone=public --add-port=9090/tcp ; firewall-cmd --permanent --zone=public --add-port=3000/tcp ; firewall-cmd --reload
  
Запускаем и активируем сервисы  
  
    - name: MONITOR SERVER | START NODE_EXPORTER
      systemd:
        name: node_exporter
        state: started
        enabled: yes
        
    
    - name: MONITOR SERVER | START PROMETHEUS
      systemd:
        name: prometheus
        state: started
        enabled: yes    


    - name: MONITOR SERVER | START GRAFANA
      systemd:
        name: grafana-server
        state: started
        enabled: yes 
        
 Создаем источник данных для grafana       
    
    - name: MONITOR SERVER | CREATE GRAFANA DATA SOURCE
      community.grafana.grafana_datasource:
        name: Prometheus
        ds_type: prometheus
        ds_url: http://192.168.100.6:9090
        access: direct
        grafana_url: "http://192.168.100.6:3000/"
        grafana_user: "admin"
        grafana_password: "admin"
        is_default: yes
        state: present
      
Создаем dashboard на основе заготовленного json    
    
    - name: MONITOR SERVER | COPY GRAFANA JSON
      copy:
        src: files/dashboard.json
        dest: /root
        force: yes 
        
    
    - name: MONITOR SERVER | IMPORT GRAFANA DASHBOARD
      grafana_dashboard:
        grafana_url: "http://192.168.100.6:3000/"
        state: present
        commit_message: Updated by ansible
        overwrite: yes
        grafana_user: "admin"
        grafana_password: "admin"
        path: /root/dashboard.json
        
Далее идет блок для сервера сбора логов

    #==================================== LOGS SERVER ==================================================    
    
Настраиваем пассивный режим работы демона systemd-journal-remote  
    
    - name: LOGS SERVER | CREATE DIR FOR JORNAL-REMOTE
      file:
        path: /var/log/journal/remote
        state: directory
        recurse: yes
        group: systemd-journal-remote
        owner: systemd-journal-remote
        
Настраиваем запуск демона systemd-journal-remote при старте системы

    - name: LOGS SERVER  | COPY  systemd-journal-remote.timer
      copy:
        src: files/systemd-journal-remote.timer
        dest: /etc/systemd/system/
       force: yes    
       
Копируем измененный unit systemd-journal-remote.service

    - name: LOGS SERVER  | COPY  systemd-journal-remote.service
      copy:
        src: files/systemd-journal-remote.service
        dest: /etc/systemd/system/
        force: yes   
        
Настраиваем файрволл для работы сбора логов    
    
    - name: LOGS SERVER  | CONFIG FIREWALLD FOR LOGS
      shell: firewall-cmd --permanent --zone=public --add-port=19532/tcp ; firewall-cmd --reload
      
 Перезагружаем демоны и стартуем сервисы     
    
    - name: LOGS SERVER  | DAEMON RELOAD
      systemd:
        daemon-reload: yes 
        
    
    - name: LOGS SERVER  | ENABLE AND START systemd-journal-remote.timer 
      systemd:
        name: systemd-journal-remote.timer
        enabled: yes
        state: started     
        
        
    - name: LOGS SERVER  | ENABLE AND START systemd-journal-remote.socket 
      systemd:
        name: systemd-journal-remote.socket
        enabled: yes
        state: started  


    - name: LOGS SERVER  | ENABLE AND START systemd-journal-remote.service 
      systemd:
        name: systemd-journal-remote.service
        enabled: yes
        state: started  
        
Настраиваем SELinux для работы сервера сбора логов

    - name: LOGS SERVER  | CONFIGURE SELINUX FOR JOURNAL-REMOTE
      shell: setsebool -P use_virtualbox 1       
   
#### 4. После провижинига и запуска сервисов на клиентских машинах проверяем сбор логов

Например, для сервера Web:
    
    # journalctl --file /var/log/journal/remote/remote-192.168.100.3.journal
    
### Файлы для настройки сервера логов и монитора

#### files/prometheus.service

    [Unit]
    Description=Prometheus
    Wants=network-online.target
    After=network-online.target

    [Service]
    User=prometheus
    Group=prometheus
    ExecStart=/bin/prometheus \
        --config.file /etc/prometheus/prometheus.yml \
        --storage.tsdb.path /var/lib/prometheus/ \
        --web.console.templates=/etc/prometheus/consoles \
        --web.console.libraries=/etc/prometheus/console_libraries

    [Install]
    WantedBy=default.target
    
#### files/systemd-journal-remote.service    

    [Unit]  
    Description=Journal Remote Sink Service  
    Requires=systemd-journal-remote.socket  

    [Service]  
    ExecStart=/usr/lib/systemd/systemd-journal-remote --listen-http=-3 --output=/var/log/journal/remote/  
    User=systemd-journal-remote  
    Group=systemd-journal-remote  
    PrivateTmp=yes  
    PrivateDevices=yes  
    PrivateNetwork=yes  
    WatchdogSec=10min  

    [Install]
    Also=systemd-journal-remote.socket 
    
#### files/systemd-journal-remote.timer    

    [Unit]
    Description=Timer For system-journal-remote

    [Timer]
    OnActiveSec=1s

    [Install]
    WantedBy=multi-user.target

#### files/dashboard.json, prometheus.yml

Эти файлы служат для автоматической настройки prometheus+grafana
    


    
