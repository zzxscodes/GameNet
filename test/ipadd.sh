#!/bin/bash
for i in {0..9}; do
    ifconfig ens33:$i 192.168.1.$((100 + $i)) netmask 255.255.255.0 up
done