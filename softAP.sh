#!/bin/bash

# Check that default IP address for LAN/WLAN located on the same network segment
# at the same ragne, that presented on $(pwd)/dnsmasq.conf (current directory of this project)

DEFAULT_WLAN_IP="192.168.30.1/255.255.255.0"
DEFAULT_LAN_IP="192.168.40.1/255.255.255.0"



# This is simple section, define color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
SET='\033[0m'


FILE_HOSTAPD=/etc/default/hostapd
FILE_DNSMASQ=/etc/dnsmasq.conf
FILE_IFACE_CFG=$(pwd)/iface.cfg

DIR_BACKUP=$(pwd)/backup
BACKUP_IPTABLES_RULES=$(pwd)/backup/backup_iptables.rules
BACKUP_DNSMASQ=$(pwd)/backup/dnsmasq.conf
BACKUP_HOSTAPD=$(pwd)/backup/hostapd


# Check dependencies
# to run softAP usually need following package:
# - hostapd
# - dnsmasq
function check_dependencies(){
	if [ ! -f "$FILE_HOSTAPD" ]; then
		echo -e "\nCan't find hostapd"
		echo -e "Try to execute ${YELLOW} sudo apt install hostapd ${SET} (Debian based distro)" 
		exit
	fi

	if [ ! -f "$FILE_DNSMASQ" ]; then
		echo -e "\nCan't find dnsmasq"
		echo -e "Try to execute ${YELLOW} sudo apt install dnsmasq ${SET} (on Debian based distro)"
		exit
	fi
}

# Show available network interface
# Create configuration file for for future use
function create_iface_config(){
	echo " "
	echo "Available network interface:"
	ip -o link show | awk -F': ' '{print "\t- " $2}'

	read -p "Set WAN  interface (press enter if you don't want to use ): " wan
	read -p "Set LAN  interface (press enter if you don't want to use ): " lan
	read -p "Set WLAN interface (press enter if you don't want to use ): " wlan

	echo "" > $FILE_IFACE_CFG

	if [ ! -z "$wan" ]; then
		echo 'wan="'$wan'"' >> $FILE_IFACE_CFG
	fi

	if [ ! -z "$lan" ]; then
		echo 'lan="'$lan'"' >> $FILE_IFACE_CFG
	fi

	if [ ! -z "$wlan" ]; then
		echo 'wlan="'$wlan'"' >> $FILE_IFACE_CFG
	fi

}

function update_iptables(){

	echo -e "[${GREEN} info ${SET}] Backup current iptables to: ${GREEN} $DIR_BACKUP ${SET}"

	iptables-save > "$BACKUP_IPTABLES_RULES"

	if [ $lan != "" ]; then
		echo -e "[${GREEN} info ${SET}] update iptables for LAN"
		iptables -A FORWARD -i $lan -o $wan -j ACCEPT
		iptables -A FORWARD -i $wan -o $lan -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 
	fi

	if [ $wlan != "" ]; then
		echo -e "[${GREEN} info ${SET}] update iptables for WLAN"
		iptables -A FORWARD -i $wlan -o $wan -j ACCEPT
		iptables -A FORWARD -i $wan -o $wlan -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
	fi

	if [ $wlan != "" ] && [ $lan != "" ]; then
		echo -e "[${GREEN} info ${SET}] allow traffic between LAN and WLAN"
		iptables -A FORWARD -i $wlan -o $lan -j ACCEPT
		iptables -A FORWARD -i $lan -o $wlan -j ACCEPT
	fi
	
	iptables -t nat -A POSTROUTING -o $wan -j MASQUERADE

}

function run_softap() {

	yes_no_iptables="n"

	while [ $yes_no_iptables != 'y' ]
	do

		if [ ! -f "$FILE_IFACE_CFG" ]; then
			echo "don't discover cfg file"
			create_iface_config
		fi

		. $FILE_IFACE_CFG

		echo "Folloging configuration will be add to iptables/implement in softAP:"
		echo -e "\t- interface LAN:  $lan"
		echo -e "\t- interface WLAN: $wlan"
		echo -e "\t- interface WAN:  $wan"

		read -p "Do you agree with configuration above (y/n)? " yes_no_iptables

		if [ "$yes_no_iptables" == 'n' ]; then
			create_iface_config
		fi

	done

	update_iptables $lan $wlan $wan

	echo -e "[${GREEN} info ${SET}] Backup current ${GREEN} $FILE_HOSTAPD ${SET} \t to: ${GREEN} $DIR_BACKUP ${SET}"	
	cp "$FILE_HOSTAPD" "$DIR_BACKUP"

	echo -e "[${GREEN} info ${SET}] Backup current ${GREEN} $FILE_DNSMASQ ${SET} \t to: ${GREEN} $DIR_BACKUP ${SET}"
	cp "$FILE_DNSMASQ" "$DIR_BACKUP"

	echo -e "[${GREEN} info ${SET}] update $FILE_HOSTAPD"
	echo 'DAEMON_CONF="'"$(pwd)/hostapd.conf"'"' > $FILE_HOSTAPD

	echo -e "[${GREEN} info ${SET}] update $FILE_DNSMASQ"
	cat $(pwd)/dnsmasq.conf > $FILE_DNSMASQ

	if [ $wlan != "" ]; then
			echo -e "[${GREEN} info ${SET}] Setup default IP address for wlan"
			echo -e "[${GREEN} info ${SET}] \t $DEFAULT_WLAN_IP"
			ip address add "$DEFAULT_WLAN_IP" dev $wlan
	fi

	if [ "$lan" != "" ]; then
			echo -e "[${GREEN} info ${SET}] Setup default IP address for lan"
			echo -e "[${GREEN} info ${SET}] \t $DEFAULT_LAN_IP"
			ip address add "$DEFAULT_LAN_IP" dev $lan
	fi


	systemctl start dnsmasq.service

	systemctl start	hostapd.service

	running_softAP=$(grep -ir "ssid=" "$(pwd)/hostapd.conf" | grep -v "#ssid" | awk -F'=' '{print $2}')
	current_password=$(grep -ir "wpa_passphrase" "$(pwd)/hostapd.conf" | grep -v "#wpa_passphrase" | awk -F'=' '{print $2}')

	echo -e "[${GREEN} info ${SET}]${GREEN} $running_softAP ${SET} is running"
	echo -e "[${GREEN} info ${SET}]${GREEN} $current_password ${SET} - password"

}

function stop_softap() {
	echo "stop softAP"

	echo -e "[${GREEN} info ${SET}] Restore iptables from backup: \t\t ${GREEN} $BACKUP_IPTABLES_RULES ${SET}"
	iptables-restore < "$BACKUP_IPTABLES_RULES"

	echo -e "[${GREEN} info ${SET}] Restore original hostapd from backup: \t ${GREEN} $BACKUP_HOSTAPD ${SET}"
	cat "$BACKUP_HOSTAPD" > "$FILE_HOSTAPD"
	
	echo -e "[${GREEN} info ${SET}] Restore original dnsmasq from backup: \t ${GREEN} $BACKUP_DNSMASQ ${SET}"
	cat "$BACKUP_DNSMASQ" > "$FILE_DNSMASQ"

	systemctl stop dnsmasq.service

	systemctl stop	hostapd.service

	. $FILE_IFACE_CFG

	if [ "$wlan" != "" ]; then
			echo -e "[${GREEN} info ${SET}] Remove IP address for wlan ($DEFAULT_WLAN_IP)"
			ip addr del "$DEFAULT_WLAN_IP" dev wlan1
	fi

	if [ "$lan" != "" ]; then
			echo -e "[${GREEN} info ${SET}] Remove IP address for lan ($DEFAULT_LAN_IP)"
			ip addr del "$DEFAULT_LAN_IP" dev eth0

	fi

	# add section for remove all backup files from "backup" folder

}

function help(){
	echo "This is simple script which run software AP"
	echo "before start this script check that 'hostapd' and 'dnsmasq' package are installed"
	echo ""
	echo "Usage:"
	echo "- run softAP:"
	echo -e " $sudo ./softAP on"
	echo -e "\t before running, script make backup:"
	echo -e "\t - current iptables"
	echo -e "\t - original $FILE_DNSMASQ"
	echo -e "\t - original $FILE_HOSTAPD"
	echo ""
	echo "It is strongly recommended for stop software AP use following command:"
	echo "$sudo ./softAP off"
	echo -e "\t after stop, script restore following:"
	echo -e "\t - iptables from backup"
	echo -e "\t - $FILE_DNSMASQ from backup"
	echo -e "\t - $FILE_HOSTAPD from backup"
}

check_dependencies

# This backup directory contain default config file
# which was created by hostapd, dnsmaq
if [ ! -d $DIR_BACKUP ]; then
	echo -e "Directory ${GREEN}backup${SET} will be created: $(pwd)"
	mkdir backup
fi

# Read argument
# $ sudo ./softAP.sh on/off
current_status_ap=$1

case $current_status_ap in
	"on")
		# echo "soft AP on"
		if [ $(systemctl is-active dnsmasq.service) == "active" ]; then
			echo -e "[${YELLOW} warning ${SET}]service dnsmasq already run"
			echo -e "[${YELLOW} warning ${SET}]it look like that 'softAP' also already run"
			exit
		fi

		if [ $(systemctl is-active hostapd.service) == "active" ]; then
			echo -e "[${YELLOW} warning ${SET}]service hostapd already run"
			echo -e "[${YELLOW} warning ${SET}]it look like that 'softAP' also already run"
			exit
		fi

		run_softap
		;;

	"off")
		if [ $(systemctl is-active dnsmasq.service) == "inactive" ]; then
			echo -e "[${YELLOW} warning ${SET}]service dnsmasq already stop"
			echo -e "[${YELLOW} warning ${SET}]it look like that 'softAP' already stoping"
			exit
		fi

		if [ $(systemctl is-active hostapd.service) == "inactive" ]; then
			echo -e "[${YELLOW} warning ${SET}]service hostapd already stop"
			echo -e "[${YELLOW} warning ${SET}]it look like that 'softAP' already stoping"
			exit
		fi		

		stop_softap
		;;

	"-h")
		help
		;;
	*)
		echo "don't recognize argument"
		;;
esac