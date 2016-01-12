# EasyOpenVPN
Simple (ish) script for installation of OpenVPN server.

Confirmed working on fresh machine, though testing is still ongoing. Let me know if you have issues.

#### This script performs the following:
- Installs all necessary packages.
- Configures server.
- Sets up certificate authority and builds server keys and certs.
- Implements 3DES and HMAC.
- Creates simple script for generating user .ovpn files containing all the necessary keys and certificates the client needs to connect.
- Enables IP forwarding and Masquerading.

#### Requires minimal user input:
- Give the required information ONCE, then never again.
- Most requirements gleaned from system automagically (network device, ip, subnet, etc).
- Configuration gets written to user creation scripts for later use, so you don't have to repeat yourself.

#### Using this script:
1. Clone or copypasta. (Optional) Change the demographic data at the top of the script.
2. Run the install script. It'll ask a few server-relevant questions at the beginning.
3. Use the script /etc/openvpn/createUser.sh to build new users.
4. Retrieve their .ovpn files from /etc/openvpn/easy-rsa/keys/ and transfer to clients for connecting.

Notes:
- This script uses Expect to emulate a user terminal environment (so it can pretend to input things on your behalf). This is used both by the installer and by the user creation script. If you've already completed the setup and created all your users, you can remove Expect and recover ~60mb of disk space.
