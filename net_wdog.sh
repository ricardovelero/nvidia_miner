#!/bin/bash
# Simple SHELL script for Linux and UNIX system monitoring with
# ping command


# add ip / hostname separated by white space
HOST="ethermine.org"

# email report when
SUBJECT="Ping failed"
EMAILID="prospector@localhost"

COUNT=4

PING=$(ping -c $COUNT $HOST | grep 'received' | awk -F',' '{ print $2 }' | awk '{ print $1 }')

if [[ $PING -lt 2 ]] || [[ $PING = *"unknown host"* ]]; then
	echo "$HOST is down (ping failed) at $(date). Will try to restart networking" | mail -s "$SUBJECT" $EMAILID
	sudo systemctl restart networking.service
fi
