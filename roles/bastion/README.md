#### Настройка сервера Bastion

Для фильтрации трафика используются правила следующие правила цепочки FORWARD  
таблицы filter:  

    iptables -P FORWARD DROP  
    iptables -t filter -A FORWARD -p tcp -m multiport --sport 80,443,3000 -j ACCEPT  
    iptables -t filter -A FORWARD -p tcp -m multiport --dport 80,443,3000 -j ACCEPT  

Таким образом, внутрь проходят только пакеты с портами назначения 80, 443 и 3000.  
  
Для проброса портов используем следующие правила цепочек PREROUTING и POSTROUTING  
таблицы nat:  
  
    iptables -t nat -A PREROUTING -p tcp -i eth1 -d 192.168.0.100 --dport 80 -j DNAT --to-destination 192.168.100.3:80
    iptables -t nat -A PREROUTING -p tcp -i eth1 -d 192.168.0.100 --dport 443 -j DNAT --to-destination 192.168.100.3:443
    iptables -t nat -A PREROUTING -p tcp -i eth1 -d 192.168.0.100 --dport 3000 -j DNAT --to-destination 192.168.100.6:3000
    iptables -t nat -A POSTROUTING -j MASQUERADE

В плейбук project.yml для настройки сервера после поднятия исполльзуется роль bastion. Далее идет описание  
файла task/main.yml.  

    # tasks file for bastion  
    - name: BASTION SERVER | COPY iptables_restore.sh  
      copy:  
        src: files/iptables_restore.sh  
        dest: /root  
        
Копируем созданный заранее файл с правилами IPTABLES

    - name: BASTION SERVER | COPY IPTABLES FILE  
      copy:  
        src: files/iptables-save  
        dest: /etc/  
    
Копируем файл юнита для восстановления правил из файла      
    
    - name: BASTION SERVER | COPY MYIPTABLES-RESTORE UNIT
      copy:
        src: files/myiptables-restore.service
        dest: /etc/systemd/system/  
        
Устанавливаем и активируем форвардинг   

    - name: BASTION SERVER | SET ip_forward
      sysctl:
        name: net.ipv4.ip_forward
        value: 1
        sysctl_set: yes
        state: present
        reload: yes
          
    - name: BASTION SERVER | ENABLE ip_forward
      lineinfile:
        dest: /etc/sysctl.conf
        line: net.ipv4.ip_forward = 1   
        
 Перезагружаем деионы systemd       
    
    - name: BASTION SERVER | DAEMON RELOAD
      systemd:
        daemon-reload: yes 
    
Активируем сервис    
        
    - name: BASTION SERVER | ENABLE myiptables-restore.service 
      systemd:
        name: myiptables-restore.service
        enabled: yes

Далее идет настройка отправки логов на центральный сервер

    #================================ Configure logs ===================================================    
 
Устанавливаем необходимые пакеты

    - name: BASTION SERVER FOR LOGS | INSTALL PACKAGES
      yum:
        name: 
          - systemd-journal-gateway
          - setools-console
          - setroubleshoot-server
          - systemd-journal-gateway
        state: present
  
Настраиваем systemd-journal-gateway и firewalld

    - name: BASTION SERVER FOR LOGS | ADD LOGS SERVER TO /etc/systemd/journal-upload.conf
      lineinfile: 
        path: /etc/systemd/journal-upload.conf
        line: URL=http://192.168.100.6:19532
        state: present

    - name: BASTION SERVER FOR LOGS | CONFIG FIREWALLD FOR LOGS
      shell: firewall-cmd --permanent --zone=public --add-port=19532/tcp ; firewall-cmd --reload
  
Стартуем сервис поднятия таблиц IPTABLES

    - name: BASTION SERVER | START myiptables-restore.service 
      systemd:
        name: myiptables-restore.service
        state: started    
  
Настраиваем SELinux для корректной работы передачи логов

    - name: BASTION SERVER FOR LOGS | CONFIGURE SELINUX FOR JOURNAL-REMOTE
      shell: semanage port -a -t dns_port_t -p tcp 19532    
  
Запускаем systemd-journal-upload.service

    - name: BASTION SERVER FOR LOGS | ENABLE AND START systemd-journal-upload.service 
      systemd:
        name: systemd-journal-upload.service
        enabled: yes
        state: started 
