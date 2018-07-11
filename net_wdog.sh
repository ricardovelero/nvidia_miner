#!/bin/bash
# Simple SHELL script for Linux and UNIX system monitoring with
# ping command


# add ip / hostname separated by white space
HOSTS="ethermine.org theos.in solucionesio.es"

# email report when
SUBJECT="Ping failed"
EMAILID="prospector@localhost"

# no ping request
COUNT=4
RECOUNT=0
re='^[0-9]+$'

for myHost in $HOSTS
do
	count=$(ping -c $COUNT $myHost | grep 'received' | awk -F',' '{ print $2 }' | awk '{ print $1 }')
	if [[ $COUNT -lt 2 ]] || [[ $COUNT = *"unknown host"* ]]; then
		echo "Host : $myHost is down (ping failed) at $(date)" | mail -s "$SUBJECT" $EMAILID
	fi
	if [[ $COUNT =~ $re ]] ; then
		RECOUNT=$(($RECOUNT + $count))
	else
		echo "Host : could not resolve $myHost (ping failed) at $(date)" | mail -s "$SUBJECT" $EMAILID
		sudo systemctl restart networking.service >/dev/null 2>&1
	fi
done

if [ $RECCOUNT -lt 8 ]; then
	# 70% failed, restart network service
	sudo systemctl restart networking.service >/dev/null 2>&1
fi
