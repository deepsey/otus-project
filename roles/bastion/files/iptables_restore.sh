#!/bin/bash

cat /etc/iptables-save | iptables-restore
