#!/bin/bash
NET=eth0
SERVERPORT=1194

if grep -Fxq "# START OPENVPN RULES" /etc/ufw/before.rules
then
echo "UFW before.rules already configured."
else

cat << UFWBEFORE >> /etc/ufw/before.rules
# START OPENVPN RULES
# NAT table rules
*nat
:POSTROUTING ACCEPT [0:0]
# Allow traffic from OpenVPN client to $NET
-A POSTROUTING -s 10.8.0.0/8 -o $NET -j MASQUERADE
COMMIT
# END OPENVPN RULES

UFWBEFORE

fi

sed -i 's/\(DEFAULT_FORWARD_POLICY=\).*/\1"ACCEPT"/' /etc/default/ufw
ufw allow $SERVERPORT
ufw reload


