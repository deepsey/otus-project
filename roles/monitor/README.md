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

#=========================== MONITORING SERVER ============================================================

- name: MONITOR SERVER | CHANGE HOSTS FILE
  blockinfile:
    path: /etc/hosts
    block: |
      192.168.100.2 project-bastion
      192.168.100.3 project-web
      192.168.100.4 project-mysql
      192.168.100.5 project-backup
    state: present
##  lineinfile: 
##    path: /etc/hosts
##    line: 192.168.100.4 project-mysql
##    state: present

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
    
- name: MONITOR SERVER | COPY PROMETHEUS CONFIG
  copy:
    src: files/prometheus.yml
    dest: /etc/prometheus/
    force: yes
    
- name: MONITOR SERVER | COPY PROMETHEUS UNIT
  copy:
    src: files/prometheus.service
    dest: /etc/systemd/system/
    force: yes 
    
- name: MONITOR SERVER | DAEMON RELOAD
  systemd:
    daemon-reload: yes 
    
- name: MONITOR SERVER | CONFIG FIREWALLD FOR PROMETHEUS
  shell: firewall-cmd --permanent --zone=public --add-port=9100/tcp ; firewall-cmd --permanent --zone=public --add-port=9090/tcp ; firewall-cmd --permanent --zone=public --add-port=3000/tcp ; firewall-cmd --reload
  
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
    
#==================================== LOGS SERVER ==================================================    
    
- name: LOGS SERVER | CREATE DIR FOR JORNAL-REMOTE
  file:
    path: /var/log/journal/remote
    state: directory
    recurse: yes
    group: systemd-journal-remote
    owner: systemd-journal-remote

- name: LOGS SERVER  | COPY  systemd-journal-remote.timer
  copy:
    src: files/systemd-journal-remote.timer
    dest: /etc/systemd/system/
    force: yes    
- name: LOGS SERVER  | COPY  systemd-journal-remote.service
  copy:
    src: files/systemd-journal-remote.service
    dest: /etc/systemd/system/
    force: yes     
    
- name: LOGS SERVER  | CONFIG FIREWALLD FOR LOGS
  shell: firewall-cmd --permanent --zone=public --add-port=19532/tcp ; firewall-cmd --reload
    
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

- name: LOGS SERVER  | CONFIGURE SELINUX FOR JOURNAL-REMOTE
  shell: setsebool -P use_virtualbox 1       
   
