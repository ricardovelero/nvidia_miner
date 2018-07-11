#!/usr/bin/env bash

#
# telegram.sh

# Load global settings settings.conf
if ! source ~/settings.conf; then
	echo "FAILURE: Can not load global settings 'settings.conf'"
	exit 9
fi

SYSTEM_BOOT_TIME=$(uptime -s)

SYSTEM_UP_TIME=$(uptime -p)

GPU_COUNT=$(nvidia-smi -i 0 --query-gpu=count --format=csv,noheader,nounits)

MINER_UP_TIME=$(ps -p `pgrep miner` -o etime | grep -v ELAPSED)

CURRENTLY_MINING=$(ps ax | grep -i screen | grep miner)

GPU_UTILIZATIONS=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | tr '\n' '   ')

TEMP=$(/usr/bin/nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits | tr '\n' '   ')

PD=$(/usr/bin/nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits | tr '\n' '   ')

FAN=$(/usr/bin/nvidia-smi --query-gpu=fan.speed --format=csv,noheader,nounits | tr '\n' '   ')

#CURRENTHASH="/usr/bin/curl -s http://localhost:3333 | sed '/Total/!d; /Speed/!d;' | awk '{print $6}' | awk 'NR == 3'"

LF=$'\n'

HEADING="Worker: $MY_RIG
Current Hashrate: $CURRENTHASH
System Boot Time: $SYSTEM_BOOT_TIME
System Up Time: $SYSTEM_UP_TIME
Miner Uptime: $MINER_UP_TIME
GPU Count: $GPU_COUNT"

MSG="$LF GPU_UTILIZATIONS: $GPU_UTILIZATIONS
$LF TEMPS: $TEMP
$LF POWERDRAW: $PD
$LF FAN SPEEDS: $FAN
$LF $CURRENTLY_MINING
$LF"

CUT_HERE="--------8<-------[ cut here ]--------"

################################################################################
# Subroutines
################################################################################

############################ Normal Message ####################################
echo_message()
{
	MSG="$HEADING$MSG$CUT_HERE"
	/usr/bin/curl -m 5 -s -X POST --output /dev/null https://api.telegram.org/bot${TELEGRAM_APIKEY}/sendMessage -d "text=${MSG}" -d chat_id=${TELEGRAM_CHATID}
}

############################ Alert Message ####################################
echo_alert()
{
	MSG="$HEADING
$LF $@
$MSG
$CUT_HERE"
	/usr/bin/curl -m 5 -s -X POST --output /dev/null https://api.telegram.org/bot${TELEGRAM_APIKEY}/sendMessage -d "text=${MSG}" -d chat_id=${TELEGRAM_CHATID}
}

###############################################################################
################################# Main Logic ##################################
###############################################################################

# Handle the command line parameters
case $# in
   0) echo_message;;
   1) case $1 in
         *)            echo_alert $@;;
      esac;;
esac
