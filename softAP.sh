#!/bin/bash

#!/bin/bash


GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
SET='\033[0m'

FILE_HOSTAPD=/etc/default/hostapd
FILE_DNSMASQ=/etc/dnsmasq.conf
DIR_BACKUP=$(pwd)/backup

net_interface=$(ls -l /sys/class/net/ | awk '{print $9}')

# Read argument
# $ sudo ./softAP.sh on/off
current_status_ap=$1


if [ ! -d $DIR_BACKUP ]; then
	echo -e "Directory ${GREEN}backup${SET} will be created: $(pwd)"
	mkdir backup
fi

if [ ! -f "$FILE_HOSTAPD" ]; then
	echo -e "\nCan't find hostapd"
	echo -e "Try to execute ${YELLOW} sudo apt install hostapd ${SET} (on Debian based distro)" 
	exit
fi

if [ ! -f "$FILE_DNSMASQ" ]; then
	echo -e "\nCan't find dnsmasq"
	echo -e "Try to execute ${YELLOW} sudo apt install dnsmasq ${SET} (on Debian based distro)"
	exit
fi


config_file=$(pwd)/hostapd.conf
configuration='DAEMON_CONF="'$config_file'"'

if grep $configuration $(pwd)/hostapd ;then
   	echo "file $(pwd)/hostapd contain link to configuration file"
else
	echo -e "This string ${GREEN}$configuration${SET} will be add to ${GREEN}$(pwd)/hostapd${SET}"
	echo "$configuration" >> $(pwd)/hostapd
fi


case $current_status_ap in
	"on")
		echo "soft AP on"
		if [ $(systemctl is-active dnsmasq.service) == "active" ]; then
			echo "service dnsmasq already run"
		else
			mv /etc/dnsmasq.conf $DIR_BACKUP
			cp dnsmasq.conf /etc
		fi

		;;

	"off")
		echo "soft AP off"

		;;

	*)
		echo "don't recognize argument"
		;;
esac


hostname --all-ip-addresses
ip addr show | grep -o "inet [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*"

# GREEN='\033[0;32m'
# RED='\033[0;31m'
# YELLOW='\033[0;33m'
# SET='\033[0m'

# FILE_HOSTAPD=/etc/default/hostapd
# FILE_DNSMASQ=/etc/dnsmasq.conf
# DIR_BACKUP=$(pwd)/backup

# net_interface=$(ls -l /sys/class/net/ | awk '{print $9}')

# # Read argument
# # $ sudo ./softAP.sh on/off
# current_status_ap=$1


# if [ ! -d $DIR_BACKUP ]; then
# 	echo -e "Directory ${GREEN}backup${SET} will be created: $(pwd)"
# 	mkdir backup
# fi



# case $current_status_ap in
# 	"on")
# 		echo -e "Try to run Soft AP \n"

# 		if [ -f "$FILE_HOSTAPD" ]; then

# 			echo -e "Make backup ${GREEN}$FILE_HOSTAPD${SET} and copy it to backup folder"
# 			mv $FILE_HOSTAPD $DIR_BACKUP
# 			cp hostap /etc/default
# 			# config_file=$(pwd)/hostapd.conf
# 			# configuration='DAEMON_CONF="'$config_file'"'

# 			# if grep $configuration $FILE_HOSTAPD;then
# 			   # echo "file '$FILE_HOSTAPD' contain link to configuration file"
# 			# else
# 			   # echo -e "This string ${GREEN}$configuration${SET} will be add to ${GREEN}$FILE_HOSTAPD${SET}"
# 			   # echo "$configuration" >> $FILE_HOSTAPD
# 			# fi

# 		else
# 			echo "Can't find hostapd"
# 			echo -e "Try to execute ${YELLOW} sudo apt install hostapd ${SET}"
# 			exit
# 		fi

# 		if [ -f "$FILE_DNSMASQ" ]; then
# 			echo $(dnsmasq --test)
# 		else
# 			echo "Can't find dnsmasq"
# 			echo -e "Try to execute ${YELLOW} sudo apt install dnsmasq ${SET}"
# 			exit
# 		fi

# 		echo "Try run dnsmasq..."
# 		systemctl start dnsmasq.service
# 		sleep 0.5s
# 		echo -e "	Status: ${GREEN}$(systemctl is-active dnsmasq.service)${SET}"

# 		echo "Try run hostapd..."
# 		systemctl start hostapd.service
# 		sleep 0.5s
# 		echo -e "	Status: ${GREEN}$(systemctl is-active hostapd.service)${SET}"
		
# 		if [ $(systemctl is-active hostapd.service) == "active" ]; then
# 			echo -e "\nSearch new AP: ${GREEN}$(grep 'ssid' $config_file | awk -F "=" '{print $2}')${SET}"
# 		fi




# 		;;
# 	"off")
# 		echo "stop AP"
# 		systemctl stop dnsmasq.service
# 		systemctl stop hostapd.service

# 		;;
# 	*)
# 		echo "don't recognize argument"
# 		;;
# esac


# grep 'ssid' hostapd.conf | awk -F "=" '{print $1}'