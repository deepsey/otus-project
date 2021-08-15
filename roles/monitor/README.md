Role Name
=========

A brief description of the role goes here.

Requirements
------------

Any pre-requisites that may not be covered by Ansible itself or the role should be mentioned here. For instance, if the role uses the EC2 module, it may be a good idea to mention in this section that the boto package is required.

Role Variables
--------------

A description of the settable variables for this role should go here, including any variables that are in defaults/main.yml, vars/main.yml, and any variables that can/should be set via parameters to the role. Any variables that are read from other roles and/or the global scope (ie. hostvars, group vars, etc.) should be mentioned here as well.

Dependencies
------------

A list of other roles hosted on Galaxy should go here, plus any details in regards to parameters that may need to be set for other roles, or variables that are used from other roles.

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: username.rolename, x: 42 }

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a website (HTML is not allowed).

History of install and configure

    1  yum search exporter
    2  yum install -y golang-github-prometheus-node-exporter
    3  vi /etc/systemd/system/node_exporter.service
    4  systemctl start node_exporter
    5  systemctl status node_exporter
    6  yum search prometheus
    7  curl 'localhost:9100/metrics'
    8  yum search prometheus
    9  yum install -y golang-github-prometheus
   10  cat /etc/systemd/system/prometheus.service
   11  systemctl start prometheus
   12  systemctl status prometheus
   13  curl 'localhost:9090/metrics'
   14  systemctl stop firewalld
   15  setenforce 0
   16  vi /etc/prometheus/prometheus.yml
   17  systemctl restart prometheus
   18  curl 'localhost:9090/metrics'
   19  ip a
   20  curl 'localhost:9000/metrics'
   21  curl 'localhost:9100/metrics'
   22  systemctl status firewalld
   23  vi /etc/prometheus/prometheus.yml
   24  curl 'localhost:9090/metrics'
   25  vi /etc/systemd/system/prometheus.service
   26  systemctl daemon-reload
   27  systemctl start prometheus
   28  curl 'localhost:9090/metrics'
   29  yum search grafana
   30  yum install -y grafana
   31  systemctl status grafana
   32  systemctl status grafana-server
   33  systemctl start grafana-server
   34  curl '192.168.100.6:9090/metrics'
   35  vi /etc/prometheus/prometheus.yml
   36  curl '192.168.100.6:9090/metrics'
   37  systemctl restart prometheus
   38  curl '192.168.100.6:9090/metrics'
   39  vi /etc/prometheus/prometheus.yml
   40  systemctl restart prometheus
   41* 
   42  vi /etc/prometheus/prometheus.yml
   43  systemctl restart prometheus
   44  systemctl status prometheus
   45  which prometheus
   46  vi /etc/systemd/system/prometheus.service
   47  systemctl daemon reload
   48  systemctl daemon-reload
   49  systemctl start prometheus
   50  systemctl status prometheus
   51  vi /etc/prometheus/prometheus.yml
   52  systemctl restart prometheus
   53  systemctl status prometheus
   54  systemctl status node_exporter
   55  history
   56  vi /etc/prometheus/prometheus.yml
   57  systemctl restart prometheus
   58  systemctl status node_exporter
   59  systemctl status prometheus
   60  vi /etc/prometheus/prometheus.yml
   61  systemctl restart prometheus
   62  systemctl status prometheus
   63  systemctl restart grafana
   64  systemctl restart grafana-server
   65  systemctl reload prometheus
   66  systemctl daemon-reload
   67  cat /etc/systemd/system/node_exporter.service
   68  systemctl restart grafana-server
   69  systemctl status grafana-server
   70  systemctl status prometheus
   71  systemctl start firewalld
   72  setenforce 1
   
   
   
   cat /etc/systemd/system/prometheus.service
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


