#!/usr/bin/env bash
# version 1.0

#
# Start mining process
#

# Load global settings settings.conf
if ! source ~/settings.conf; then
	echo "FAILURE: Can not load global settings 'settings.conf'"
	exit 9
fi

export DISPLAY=:0

# Determine the number of available GPU's
GPUS=$(nvidia-smi -i 0 --query-gpu=count --format=csv,noheader,nounits)

echo ""
echo -e "DETECTED: $GPUS GPU's"
echo ""

#Common commands
NVD="nvidia-settings"
SMI="sudo nvidia-smi"

#Declare variables
typeset -i i GPUS

# Set persistence mode
echo -e "SETTING: Persistence Mode"
echo ""
${SMI} -pm ENABLED

# Set power limit
if [ $INDIVIDUAL_POWERLIMIT == "NO" ]
then
	echo -e "SETTING: Power Limit"
	echo ""
	${SMI} -pl "$MY_WATT"
fi

if [ $INDIVIDUAL_POWERLIMIT == "YES" ]
then
	echo ""
	echo -e "SETTING: Individual Power Limits"
	echo ""
	# Loop to setup found gpus
	for ((MY_DEVICE=0;MY_DEVICE<=GPUS;++MY_DEVICE))
	do
	      # Check if card exists
	      if ${SMI} -i $MY_DEVICE >> /dev/null 2>&1; then

		get_p() { local tmp; tmp="INDIVIDUAL_POWERLIMIT_$MY_DEVICE"; printf %s "${!tmp}"; }

		${SMI} -i $MY_DEVICE -pl $(get_p)

	      fi
	done
fi

# If settings have changed after btime, then set OC
if [[ $(cat /proc/stat | grep btime | awk '{ print $2 }') -lt $(date -r settings.conf +%s) ]]
then
	echo -e "SETTING: Overcocking"
	echo ""

	~/nvidia-overclock.sh

fi

# Set Fan
if [ $AUTO_TEMP_FAN == "NO" ]
then
	echo -e "SETTING: Fixed Fan Speed"
	echo ""
	${NVD} -a "GPUFanControlState=1"
	${NVD} -a "GPUTargetFanSpeed=$MY_FAN"
fi

# Autotempfan
if [ $AUTO_TEMP_FAN == "YES" ]
then
	running=$(ps -ef | awk '$NF~"autotempfan.sh" {print $2}')
	if [ "$running" != "" ]
	then
		kill $running
	fi
	sleep 2

	running=$(ps -ef | awk '$NF~"autotempfan.sh" {print $2}')
	if [ "$running" == "" ]
	then
		echo ""
		echo "LAUNCHING:  AUTOMATIC TEMP & FAN CONTROL "

		screen -dmS temp bash ~/autotempfan.sh

		echo ""
		echo "process in screen temp; attach with alias: temp"
		echo ""
	fi
fi

# Watchdog
if [ $WATCHDOG == "YES" ]
then
	running=$(ps -ef | awk '$NF~"watchdog.sh" {print $2}')
	if [ "$running" == "" ]
	then
		echo "LAUNCHING:  MINER WATCHDOG"

		screen -dmS wdog bash ~/watchdog.sh

		echo ""
		echo "process in screen wdog; attach with alias: wdog"
		echo ""
	fi
fi

#Miner start
export GPU_FORCE_64BIT_PTR=0
export GPU_MAX_HEAP_SIZE=100
export GPU_USE_SYNC_OBJECTS=1
export GPU_MAX_ALLOC_PERCENT=100
export GPU_SINGLE_ALLOC_PERCENT=100

echo "LAUNCHING:  MINER"
# ethminer
# https://github.com/ethereum-mining/ethminer
#

#
# ETH
#

if [[ $COIN == "ETH" ]]; then

	# Please choose version
	# version 0.14 and bellow

	if [[ $USE_LEGACY_ETHMINER == "YES" ]]; then

		screen -dmS miner ~/ethminer/legacy/ethminer --farm-recheck 10000 -SP 1 -RH -S "$ETH_POOL" -FS "$ETH_FS" -O "$ETH_ADDRESS.$MY_RIG" -U

	fi

	# Version 0.15 and above

	if [[ $USE_POOL_SSL == "YES" ]] && [[ $USE_LEGACY_ETHMINER == "NO" ]]; then

		screen -dmS miner ~/ethminer/latest/ethminer -U -R -P stratum1+ssl://$ETH_ADDRESS.$MY_RIG@$ETH_POOL_SSL --api-bind -3333

	elif [[ $USE_POOL_SSL == "NO" ]] && [[ $USE_LEGACY_ETHMINER == "NO" ]]; then

		screen -dmS miner ~/ethminer/latest/ethminer -U -R -P stratum1+ssl://$ETH_ADDRESS.$MY_RIG@$ETH_POOL --api-bind -3333

	fi

fi #ETH coin IF

#
# ETC
#

if [[ $COIN == "ETC" ]]; then

	# Please choose version
	# version 0.14 and bellow

	if [[ $USE_LEGACY_ETHMINER == "YES" ]]; then

		screen -dmS miner ~/ethminer/legacy/ethminer --farm-recheck 10000 -SP 1 -RH -S "$ETC_POOL" -FS "$ETC_FS" -O "$ETC_ADDRESS.$MY_RIG" -U

	fi

	# Version 0.15 and above

	if [[ $USE_POOL_SSL == "YES" ]] && [[ $USE_LEGACY_ETHMINER == "NO" ]]; then

		screen -dmS miner ~/ethminer/latest/ethminer -U -R -P stratum1+ssl://$ETC_ADDRESS.$MY_RIG@$ETC_POOL_SSL --api-bind -3333

	elif [[ $USE_POOL_SSL == "NO" ]] && [[ $USE_LEGACY_ETHMINER == "NO" ]]; then

		screen -dmS miner ~/ethminer/latest/ethminer -U -R -P stratum1+ssl://$ETC_ADDRESS.$MY_RIG@$ETC_POOL --api-bind -3333

	fi

fi #ETC coin IF

#
# BTG
#
if [[ $COIN == "BTG" ]]; then

	if [[ $USE_POOL_SSL == "YES" ]] && [[ $USE_EWBF_OR_FUNAKOSHI_MINER == "funakoshi" ]]; then

		screen -dmS miner ~/funakoshi/latest/funakoshiMiner -l ssl://$BTG_POOL:$BTG_POOL_PORT -u $BTG_ADDRESS.$MY_RIG -p coco

	elif [[ $USE_POOL_SSL == "NO" ]] && [[ $USE_EWBF_OR_FUNAKOSHI_MINER == "funakoshi" ]]; then

		screen -dmS miner ~/funakoshi/latest/funakoshiMiner -l $BTG_POOL:$BTG_POOL_PORT -u $BTG_ADDRESS.$MY_RIG -p coco

	fi

	if [[ $USE_EWBF_OR_FUNAKOSHI_MINER == "ewbf" ]]; then

		screen -dmS miner ~/ewbf/latest/miner --algo 144_5 --server $BTG_POOL --port $BTG_POOL_PORT --user $BTG_ADDRESS.$MY_RIG --password coco --pers BgoldPoW

	fi

fi #BTG coin IF

# Claymore's Dual Ethereum+Decred AMD+NVIDIA GPU Miner
#screen -dmS miner ~/claymore-dual-miner/ethdcrminer64 -epool "eu1.ethermine.org:4444" -ewal "$MY_ADDRESS.$MY_RIG" -epsw x -mode 1 -ftime 10 -mport 0

#
# Monero Mining
#

# XMR-Stak - Monero/Aeon All-in-One Mining Software
# https://github.com/fireice-uk/xmr-stak
#cd ~/monero-mining
# CUDA (GPU) only mining. Disable the CPU miner backend.
#screen -dmS miner ~/monero-mining/xmr-stak/build/bin/xmr-stak --noCPU
# CPU only mining. Disable the NVIDIA miner backend.
#screen -dmS miner ~/monero-mining/xmr-stak/build/bin/xmr-stak --noNVIDIA


#
# Zcash Mining
#

# EWBF's CUDA Zcash Miner
# https://bitcointalk.org/index.php?topic=1707546.0
#cd ~/zcash-mining
#screen -dmS miner ~/zcash-mining/ewbf/miner --fee 0 --server eu1-zcash.flypool.org --user $ZCASH_ADDRESS --pass x --port 3333

echo "    "
echo "    "$(ps ax | grep miner | grep -o 'SCREEN.*')
echo "    "
echo "process in screen miner; attach with alias: miner"
echo ""
