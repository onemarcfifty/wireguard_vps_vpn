#!/bin/bash

# ###########################################
# ###########################################
#
# Wireguard installation script for Ubuntu 18.04
# by OneMarcFifty
# the place for digital DIY
#
# https://www.youtube.com/channel/UCG5Ph9Mm6UEQLJJ-kGIC2AQ
#
# ###########################################
# ###########################################

# ###############################
# This needs to be run as root !
# ###############################

# ###########################################
# Delete any old config
# ###########################################

rm -f "/etc/wireguard/wg0.conf"
rm -f "/etc/wireguard/privatekey"
rm -f "/etc/wireguard/publickey"

if ip -br link | grep wg0 ; then
   ip link delete wg0
fi

# ###############################
# update the software sources
# ###############################

apt update
apt install -y software-properties-common curl qrencode
add-apt-repository -y ppa:wireguard/wireguard

# ###############################
# install wireguard
# ###############################

apt install -y wireguard

# let's also clean up a little bit
# in case some redundant packages exist

apt -y autoremove

# ###############################
# generate a key pair
# ###############################


# --- this works

#touch /etc/wireguard/privatekey 
#chmod 600 /etc/wireguard/privatekey 
#cat  /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey

# --- this is more elegant

umask 077
wg genkey > /etc/wireguard/privatekey
wg pubkey < /etc/wireguard/privatekey > /etc/wireguard/publickey

# ###############################
# enable routing
# ###############################

# --- remove the comment from the forward flag in sysctl.conf
#sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

# enable ip4 forwarding with sysctl
sysctl -w net.ipv4.ip_forward=1

# --- print out the content of sysctl.conf
sysctl -p


# ###########################################
# define the wg0 interface
# ###########################################

# change this if you want
export WG0ADDRESS=192.168.88.1/24
# we are using export to allow for copy paste

ip link add dev wg0 type wireguard
ip address add dev wg0 $WG0ADDRESS
wg set wg0 private-key /etc/wireguard/privatekey
wg set wg0 listen-port 51820

# ###########################################
# up the interface
# ###########################################

#ip link set wg0 up

# --- this would not be persistent, i.e. needs to be redone afer reboot
# --- so we create a config file and make it persistent:

wg showconf wg0 > /etc/wireguard/wg0.conf

# -- the showconf command does not give the IP address so we just print it into the config file

echo "Address=$WG0ADDRESS" >> /etc/wireguard/wg0.conf
echo "SaveConfig = true" >> /etc/wireguard/wg0.conf

# find our own public IP address
# we get this info from the internet
# using curl with root is dangerous, so we
# run it as nobody


export OUR_OWN_IP=`sudo -u nobody curl -s ipinfo.io/ip`

# find out which interface the public IP address is on

readarray -d " " -t templine <<< $(ip -br addr | grep $OUR_OWN_IP)
export OUR_INTERFACE=${templine[0]}

echo "our interface:$OUR_INTERFACE:"

# The initial idea here was to find the interface that has the public IP
# address. This will not work in a NAT environment, i.e.
# where the VPS is behind a NAT router and does not have the
# public address directly.

# Fix : If we do not get an interface this way we just use the first 
# interface with the default route - we check for a minimum length of 3
# checking for zero length like this 
# [ -z "$OUR_WAN_INTERFACE" ] && export OUR_WAN_INTERFACE = ip route | grep default | sed s/.*dev\ //g | sed s/\ .*//g
# does not work because there is a line feed
# in the variable

if [ ${#OUR_INTERFACE} -le 2 ]; then
    echo "WAN Interface not found - was:${OUR_INTERFACE}:"
    export OUR_INTERFACE=`ip route | grep default | sed s/.*dev\ //g | sed s/\ .*//g`
    echo "WAN Interface is now: $OUR_INTERFACE"
fi

# At this point, our VPN Server yould just be a router
# but we want it to mask our IP address.
# Also the ISP would not route our private 192.168.88.x address
# hence we need some firewall rules added

echo "PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $OUR_INTERFACE -j MASQUERADE" >> /etc/wireguard/wg0.conf
echo "PostDOWN = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $OUR_INTERFACE -j MASQUERADE" >> /etc/wireguard/wg0.conf


# ###########################################################
# this will automatically bring up the interface after reboot
# ###########################################################

systemctl enable wg-quick@wg0.service

# ###########################################
# ###########################################


