# EasyOpenVPN
Simple (ish) script for installation of OpenVPN server.

## Still in testing. Don't use this quite yet, as it still has a couple minor hangups (easy-rsa vars writing).

#### This script performs the following:
- Installs all necessary packages.
- Configures server.
- Sets up certificate authority and builds server keys and certs.
- Creates simple script for generating user .ovpn files containing all the necessary keys and certificates the user needs to connect.
- Enables IP forwarding and Masquerading

#### Requires minimal user input
- Give the required information ONCE, then never again.
- Most requirements gleaned from system automagically (network device, ip, subnet, etc.)
- Configuration gets written to user creation scripts for later use, so you don't have to repeat yourself.


This script uses Expect to emulate a user terminal environment (so it can pretend to input things on your behalf). This is used both by the installer and by the user creation script. If you've already completed the setup and created all your users, you can remove Expect and recover ~60mb of disk space.
