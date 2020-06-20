#!/bin/bash

# ###########################################
# ###########################################
#
# Wireguard script to add a peer
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

# first parameter is the clientname
# second parameter is the IP address it gets on the VPN

[[ ! -z "$1" ]] && WGCLIENTNAME=$1 || WGCLIENTNAME=newclient
[[ ! -z "$2" ]] && WGCLIENTADDRESS=$2 || WGCLIENTADDRESS="192.168.88.2/32"

echo -e "\ngenerating peer $WGCLIENTNAME with IP $WGCLIENTADDRESS\n"


# generate a new keypair

export NEW_PRIVATE_KEY=`wg genkey`
export NEW_PUBLIC_KEY=$(echo "$NEW_PRIVATE_KEY" | wg pubkey)

# read out this server's pubkey

readarray -d : -t templine <<< $(wg | grep "public key")
export SERVER_PUBLIC_KEY=${templine[1]};
readarray -d : -t templine <<< $(wg | grep "listening port")
#SERVER_LISTENING_PORT=${templine[1]};
# we need to remove the leading space 
export SERVER_LISTENING_PORT=${templine[1]// /}

# guess our own internet address

# ip addr show | grep "scope global" |grep -v "wg0"
# echo $SSH_CONNECTION
# curl ipinfo.io/ip
# it presents a risk to curl as root so we sudo as nobody ....

export OUR_OWN_IP=`sudo -u nobody curl -s ipinfo.io/ip`

# generate the config output

export new_config_file_name=/etc/wireguard/newpeer.conf
umask 077
echo "# ######################################################" > $new_config_file_name
echo "# ########### COPY PASTE BELOW #########################" >> $new_config_file_name
echo "# ######################################################" >> $new_config_file_name
echo -e "[Interface]\nPrivateKey = $NEW_PRIVATE_KEY\nAddress=$WGCLIENTADDRESS\nDNS=8.8.8.8\n" >>$new_config_file_name
echo -e "[Peer]\nPublicKey = $SERVER_PUBLIC_KEY\nAllowedIPs=0.0.0.0/0\nEndPoint=$OUR_OWN_IP:"${SERVER_LISTENING_PORT}"\n" >> $new_config_file_name
echo "# ######################################################" >> $new_config_file_name
echo "# ########### COPY PASTE ABOVE #########################" >> $new_config_file_name
echo "# ######################################################" >> $new_config_file_name



# add the new peer to the wg0 config file

wg set wg0 peer $NEW_PUBLIC_KEY allowed-ips $WGCLIENTADDRESS

# we need to down and up the interface in order to 
# make changes persistent

wg-quick down wg0 && wg-quick up wg0

# clean out all critcal variables in case the user
# ran the script with copy/paste into the
# terminal window

export -n NEW_PRIVATE_KEY
export -n NEW_PUBLIC_KEY
export -n SERVER_PUBLIC_KEY



# show the config as a barcode
cat $new_config_file_name  | qrencode -t ANSIUTF8
# show the config as text
cat $new_config_file_name
