#!/bin/bash
# ubuntu 18.04
pass=$1
apt update
apt install shadowsocks-libev -y
mkdir -p /etc/shadowsocks-libev
cat > /etc/shadowsocks-libev/config.json << EOF
{
    "server":"0.0.0.0",
    "mode":"tcp_and_udp",
    "server_port":443,
    "local_port":1080,
    "password":"${pass}",
    "timeout":60,
    "method":"chacha20"
}
EOF
ufw disable
ufw allow proto tcp to 0.0.0.0/0 port 443 comment "Shadowsocks server listen port"
ufw enable
systemctl start shadowsocks-libev
systemctl restart shadowsocks-libev
