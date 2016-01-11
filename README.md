# EasyOpenVPN
Simple (ish) script for installation of OpenVPN server.

## Still in testing. Don't use this quite yet, as it still has a couple minor hangups, and needs further testing.

#### This script performs the following:
- Installs all necessary packages.
- Configures server.
- Sets up certificate authority and builds server keys and certs.
- Creates simple script for generating user .ovpn files containing all the necessary keys and certificates the user needs to connect.
- Enables IP forwarding and Masquerading

#### Requires minimal user input

