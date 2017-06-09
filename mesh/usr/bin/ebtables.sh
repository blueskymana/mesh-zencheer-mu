#!/bin/sh

echo "The ebtables start !"

ebtables -P FORWARD ACCEPT 
ebtables -P INPUT ACCEPT
ebtables -P OUTPUT ACCEPT
ebtables -F 
ebtables -A FORWARD -p ipv4 -i br-lan --ip-dst 172.16.16.16 -j DROP
