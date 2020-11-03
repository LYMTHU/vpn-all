#/bin/bash
# ubuntu 18.04
# ./ikev-setup.sh ip eth0 user pass
ip=$1
# get networkhw from `ip route | grep default` the word after "dev"
networkhw=$2
username=$3
pass=$4
sudo apt install -y strongswan strongswan-pki
mkdir -p ~/pki/{cacerts,certs,private}
chmod 700 ~/pki
ipsec pki --gen --type rsa --size 4096 --outform pem > ~/pki/private/ca-key.pem
ipsec pki --self --ca --lifetime 3650 --in ~/pki/private/ca-key.pem --type rsa --dn "CN=VPN root CA" --outform pem > ~/pki/cacerts/ca-cert.pem
ipsec pki --gen --type rsa --size 4096 --outform pem > ~/pki/private/server-key.pem
ipsec pki --pub --in ~/pki/private/server-key.pem --type rsa | ipsec pki --issue --lifetime 1825 --cacert ~/pki/cacerts/ca-cert.pem --cakey ~/pki/private/ca-key.pem --dn "CN=104.156.225.153" --san "104.156.225.153" --flag serverAuth --flag ikeIntermediate --outform pem >  ~/pki/certs/server-cert.pem
sudo cp -r ~/pki/* /etc/ipsec.d/
sudo mv /etc/ipsec.conf{,.original}

sudo cat > /etc/ipsec.conf << EOF
config setup
    charondebug="ike 1, knl 1, cfg 0"
    uniqueids=no

conn ikev2-vpn
    auto=add
    compress=no
    type=tunnel
    keyexchange=ikev2
    fragmentation=yes
    forceencaps=yes
    dpdaction=clear
    dpddelay=300s
    rekey=no
    left=%any
    leftid=${ip}
    leftcert=server-cert.pem
    leftsendcert=always
    leftsubnet=0.0.0.0/0
    right=%any
    rightid=%any
    rightauth=eap-mschapv2
    rightsourceip=10.10.10.0/24
    rightdns=8.8.8.8,8.8.4.4
    rightsendcert=never
    eap_identity=%identity
EOF

sudo cat > /etc/ipsec.secrets << EOF
: RSA "server-key.pem"
${username} : EAP "${pass}"
EOF
sudo systemctl restart strongswan
ip route | grep default 
sudo ufw allow OpenSSH
sudo ufw enable
sudo ufw allow 443,500,4500/udp


cat >/tmp/before.rules <<EOF
# new
*nat
-A POSTROUTING -s 10.10.10.0/24 -o ${networkhw} -m policy --pol ipsec --dir out -j ACCEPT
-A POSTROUTING -s 10.10.10.0/24 -o ${networkhw} -j MASQUERADE
COMMIT

*mangle
-A FORWARD --match policy --pol ipsec --dir in -s 10.10.10.0/24 -o ${networkhw} -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360
COMMIT
EOF
if [! -f "/etc/ufw/before.rules.bak"];then
sudo cp /etc/ufw/before.rules /etc/ufw/before.rules.bak
fi
cat /etc/ufw/before.rules.bak >>/tmp/before.rules
cat >>/tmp/before.rules <<EOF
# new
-A ufw-before-forward --match policy --pol ipsec --dir in --proto esp -s 10.10.10.0/24 -j ACCEPT
-A ufw-before-forward --match policy --pol ipsec --dir out --proto esp -d 10.10.10.0/24 -j ACCEPT
EOF
sudo mv /tmp/before.rules /etc/ufw/before.rules

if [! -f "/etc/ufw/sysctl.conf.bak"];then
sudo cp /etc/ufw/sysctl.conf /etc/ufw/sysctl.conf.bak
fi
sudo cat /etc/ufw/sysctl.conf.bak > /etc/ufw/sysctl.conf
sudo cat > /etc/ufw/sysctl.conf << EOF
# new
net/ipv4/ip_forward=1
net/ipv4/conf/all/accept_redirects=0
net/ipv4/conf/all/send_redirects=0
net/ipv4/ip_no_pmtu_disc=1
EOF
