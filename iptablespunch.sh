#!/bin/bash
NET=
LOCAL_IP=

# Enable iptables masquerading if not already done.
iptables -t nat -C POSTROUTING -o $NET -j MASQUERADE &>/dev/null
CHECK=$?
if [ $CHECK -eq 0 ]; then
echo "Iptables rules already exist (1)."
else
iptables -t nat -A POSTROUTING -o $NET -j MASQUERADE
fi

iptables -t nat -C POSTROUTING -s 10.8.0.0/24 -o $NET -j SNAT --to-source $LOCAL_IP &>/dev/null
CHECK=$?
if [ $CHECK -eq 0 ]; then
echo "Iptables rules already exist (2)."
else
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $NET -j SNAT --to-source $LOCAL_IP
fi

DEBIAN_FRONTEND=noninteractive dpkg-reconfigure iptables-persistent

