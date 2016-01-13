#!/bin/bash

CERT_KEY_COUNTRY="US"
CERT_KEY_PROVINCE="Kansas"
CERT_KEY_CITY="Lawrence"
CERT_KEY_ORG="Openvpn"
CERT_KEY_EMAIL="user@herp.derp"
CERT_KEY_OU="Infrastructure"
CERT_KEY_NAME="Openvpn"
# This can probably be left on 2048. 4096 is bananas.
CERT_KEY_SIZE="2048"



# SCRIPT STARTS HERE

if [[ $EUID -ne 0 ]]; then
	echo "This script requires elevated privileges to run. Are you root?"
	exit
fi

read -p "Resolvable domain name or external IP address of server: " DOMAIN
read -p 'Provide a name for the OpenVPN server (default "server"): ' CN
read -p "Port on which OpenVPN will be available (default 1194): " PORT
read -p "Address of DNS nameserver that clients will use (default 8.8.8.8): " DNS
read -p "Network interface for OpenVPN (default eth0): " NET

# Get some environment and system variables
DATE=$(date +"%Y%m%d%H%M")
LOCAL_IP=$(ip route get 8.8.8.8 | awk '{ print $NF; exit }')
IP_BASE=`echo $LOCAL_IP | cut -d"." -f1-3`
LOCAL_SUBNET=`echo $IP_BASE".0"`
# Get network interface name

if [ -z "$CN" ]; then
	CN="server"
	fi
if [ -z "$PORT" ]; then
	PORT="1194"
	fi
if [ -z "$DNS" ]; then
	DNS="8.8.8.8"
	fi
if [ -z "$NET" ]; then
	NET="eth0"
	fi

echo "Updating and upgrading packages..."
DEBIAN_FRONTEND=noninteractive apt-get update &>/dev/null && apt-get upgrade -y &>/dev/null
echo "Installing new packages..."
DEBIAN_FRONTEND=noninteractive apt-get install openvpn easy-rsa expect iptables-persistent -y &>/dev/null

cp /usr/share/easy-rsa /etc/openvpn/easy-rsa -r

cd /etc/openvpn/easy-rsa/

cp vars vars.backup$DATE
sed -i "s/\(KEY_COUNTRY=\).*/\1$CERT_KEY_COUNTRY/" vars
sed -i "s/\(KEY_PROVINCE=\).*/\1$CERT_KEY_PROVINCE/" vars
sed -i "s/\(KEY_CITY=\).*/\1$CERT_KEY_CITY/" vars
sed -i "s/\(KEY_ORG=\).*/\1$CERT_KEY_ORG/" vars
sed -i "s/\(KEY_EMAIL=\).*/\1$CERT_KEY_EMAIL/" vars
sed -i "s/\(KEY_OU=\).*/\1$CERT_KEY_OU/" vars
sed -i "s/\(KEY_NAME=\).*/\1$CERT_KEY_NAME/" vars
sed -i "s/\(KEY_SIZE=\).*/\1$CERT_KEY_SIZE/" vars

source ./vars
./clean-all

# Build the certificate authority
expect << EOF
spawn ./build-ca
expect "Country Name" { send "\r" }
expect "State" { send "\r" }
expect "Locality" { send "\r" }
expect "Organization Name" { send "\r" }
expect "Organizational Unit" { send "\r" }
expect "Common Name" { send "$CN\r" }
expect "Name" { send "$CN\r" }
expect "Email" { send "\r" }
expect eof
EOF

# Build server certificate
expect << EOF
spawn ./build-key-server $CN
expect "Country Name" { send "\r" }
expect "State" { send "\r" }
expect "Locality" { send "\r" }
expect "Organization Name" { send "\r" }
expect "Organizational Unit" { send "\r" }
expect "Common Name" { send "$CN\r" }
expect "Name" { send "$CN\r" }
expect "Email" { send "\r" }
expect "challenge password" { send "\r" }
expect "company name" { send "\r" }
expect "the certificate" { send "y\r" }
expect "commit" { send "y\r" }
expect eof
EOF

# Generate Diffie-Hellman key
./build-dh

# Generate HMAC key
openvpn --genkey --secret keys/ta.key

# Write the server config file for openvpn
cat <<EOT > /etc/openvpn/$CN.conf
local $LOCAL_IP
dev tun
proto udp
port $PORT
ca /etc/openvpn/easy-rsa/keys/ca.crt
cert /etc/openvpn/easy-rsa/keys/$CN.crt
key /etc/openvpn/easy-rsa/keys/$CN.key
dh /etc/openvpn/easy-rsa/keys/dh$CERT_KEY_SIZE.pem
server 10.8.0.0 255.255.255.0
ifconfig 10.8.0.1 10.8.0.2
push "route 10.8.0.1 255.255.255.255"
push "route 10.8.0.0 255.255.255.0"
push "route $LOCAL_SUBNET 255.255.255.0"
push "dhcp-option DNS $DNS"
push "redirect-gateway def1"
client-to-client
duplicate-cn
keepalive 10 120
tls-auth /etc/openvpn/easy-rsa/keys/ta.key 0
cipher AES-128-CBC
comp-lzo
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn-status.log 20
log /var/log/openvpn.log
verb 1

EOT

# Write client template file for OVPN client
cat <<EOT > /etc/openvpn/easy-rsa/client-template.txt
client
dev tun
proto udp
remote $DOMAIN $PORT
resolv-retry infinite
nobind
persist-key
persist-tun
mute-replay-warnings
ns-cert-type server
key-direction 1
cipher AES-128-CBC
comp-lzo
verb 1
mute 20
EOT

# Write OVPN parsing script. Builds OVPN from components
cat <<"EOT" > /etc/openvpn/easy-rsa/makeOVPN.sh

#!/bin/bash

# Default Variable Declarations
DEFAULT="client-template.txt"
FILEEXT=".ovpn"
CRT=".crt"
KEY=".3des.key"
CA="ca.crt"
TA="ta.key"
NAME=$1

#1st Verify that client's Public Key Exists
if [ ! -f $NAME$CRT ]; then
 echo "[ERROR]: Client Public Key Certificate not found: $NAME$CRT"
 exit
fi
echo "Client's cert found: $NAME$CR"

#Then, verify that there is a private key for that client
if [ ! -f $NAME$KEY ]; then
 echo "[ERROR]: Client 3des Private Key not found: $NAME$KEY"
 exit
fi
echo "Client's Private Key found: $NAME$KEY"

#Confirm the CA public key exists
if [ ! -f $CA ]; then
 echo "[ERROR]: CA Public Key not found: $CA"
 exit
fi
echo "CA public Key found: $CA"

#Confirm the tls-auth ta key file exists
if [ ! -f $TA ]; then
 echo "[ERROR]: tls-auth Key not found: $TA"
 exit
fi
echo "tls-auth Private Key found: $TA"

#Ready to make a new .opvn file - Start by populating with the
# default file
cat ../$DEFAULT > $NAME$FILEEXT

#Now, append the CA Public Cert
echo "<ca>" >> $NAME$FILEEXT
cat $CA >> $NAME$FILEEXT
echo "</ca>" >> $NAME$FILEEXT

#Next append the client Public Cert
echo "<cert>" >> $NAME$FILEEXT
cat $NAME$CRT | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' >> $NAME$FILEEXT
echo "</cert>" >> $NAME$FILEEXT

#Then, append the client Private Key
echo "<key>" >> $NAME$FILEEXT
cat $NAME$KEY >> $NAME$FILEEXT
echo "</key>" >> $NAME$FILEEXT

#Finally, append the TA Private Key
echo "<tls-auth>" >> $NAME$FILEEXT
cat $TA >> $NAME$FILEEXT
echo "</tls-auth>" >> $NAME$FILEEXT

echo "Done! $NAME$FILEEXT Successfully Created."

#Script written by Eric Jodoin
# Cleaned up by Dustin Horvath. Modified to take user as cli argument.
\
EOT
chmod +x /etc/openvpn/easy-rsa/makeOVPN.sh

# Write user creation script.
cat <<"CREATEUSER" > /etc/openvpn/createUser.sh
#!/bin/bash

read -p "Username of new client: " USER
while true
do
    read -s -p "Create user password: " PW
    echo
    read -s -p "Confirm password: " PW2
    echo
    [ "$PW" = "$PW2" ] && break
    echo "Mismatch. Please try again."
done
cd /etc/openvpn/easy-rsa
source ./vars

# Generate client certificate and key
expect << EOF
spawn ./build-key-pass $USER
expect "Enter PEM pass phrase" { send "$PW\r" }
expect "Verifying - Enter PEM pass phrase" { send "$PW\r" }
expect "Country Name" { send "\r" }
expect "State" { send "\r" }
expect "Locality" { send "\r" }
expect "Organization Name" { send "\r" }
expect "Organizational Unit" { send "\r" }
expect "Common Name" { send "$CN\r" }
expect "Name" { send "$CN\r" }
expect "Email" { send "\r" }
expect "challenge password" { send "\r" }
expect "company name" { send "\r" }
expect "the certificate" { send "y\r" }
expect "commit" { send "y\r" }
expect eof
EOF

cd keys

# Generate client 3DES key
expect << EOF
spawn openssl rsa -in $USER.key -des3 -out $USER.3des.key
expect "pass phrase for" { send "$PW\r" }
expect "Enter PEM pass" { send "$PW\r" }
expect "Verifying - Enter PEM" { send "$PW\r" }
expect eof
EOF

# Assemble OVPN file
../makeOVPN.sh $USER

CREATEUSER

chmod +x /etc/openvpn/createUser.sh

# Backup sysctl.conf and then enable ipv4 forwarding
cp /etc/sysctl.conf /etc/sysctl.conf.backup$DATE
sed -i '/net.ipv4.ip_forward=1/s/^#//g' /etc/sysctl.conf
sysctl -p

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

service openvpn restart &>/dev/null

echo "OpenVPN setup complete."
