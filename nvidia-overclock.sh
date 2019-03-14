#!/usr/bin/env bash

#
# nvidia-overclock.sh
# Author: Nils Knieling - https://github.com/Cyclenerd/ethereum_nvidia_miner
#
# Overclocking with nvidia-settings
#

# Load global settings settings.conf
if ! source ~/settings.conf; then
	echo "FAILURE: Can not load global settings 'settings.conf'"
	exit 9
fi

export DISPLAY=:0

#Common commands
NVD="sudo DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0 nvidia-settings"
SMI="sudo nvidia-smi"

#Declare variables
typeset -i i GPUS

# Determine the number of available GPU's
GPUS=$(nvidia-smi -i 0 --query-gpu=count --format=csv,noheader,nounits)

echo ""
echo -e "Detected: $GPUS GPU's"
echo ""

if [ $INDIVIDUAL_CLOCKS == "NO" ]
then
	if [[ $( $SMI --query-gpu=name --format=csv,noheader | grep -E 'CMP6-1|P106-100|1050') ]]; then
		${NVD} -c :0 -a "GPUMemoryTransferRateOffset[2]=$MY_MEM"
		${NVD} -c :0 -a "GPUGraphicsClockOffset[2]=$MY_CLOCK"
	elif [[ $( $SMI --query-gpu=name --format=csv,noheader | grep -E 'CMP4-1|P104-100') ]]; then
		${NVD} -c :0 -a "GPUMemoryTransferRateOffset[1]=$MY_MEM"
		${NVD} -c :0 -a "GPUGraphicsClockOffset[1]=$MY_CLOCK"
	else
		${NVD} -c :0 -a "GPUMemoryTransferRateOffset[3]=$MY_MEM"
		${NVD} -c :0 -a "GPUGraphicsClockOffset[3]=$MY_CLOCK"
	fi
	if [[ $GPUPowerMizerMode_Adjust == "YES" ]]
	then
		${NVD} -c :0 -a "GPUPowerMizerMode=${GPUPowerMizerMode}"
	fi
fi

if [ $INDIVIDUAL_CLOCKS == "YES" ]
then
 # Loop to setup found gpus
 for ((MY_DEVICE=0;MY_DEVICE<=GPUS;++MY_DEVICE))
 do
        # Check if card exists
        if ${SMI} -i $MY_DEVICE >> /dev/null 2>&1; then

								get_c() { local tmp; tmp="__CORE_OVERCLOCK_$MY_DEVICE"; printf %s "${!tmp}"; }
								get_m() { local tmp; tmp="MEMORY_OVERCLOCK_$MY_DEVICE"; printf %s "${!tmp}"; }

								if [[ $GPUPowerMizerMode_Adjust == "YES" ]]
  							then
                	${NVD} -a [gpu:$MY_DEVICE]/GPUPowerMizerMode=${GPUPowerMizerMode}
								fi

								if [[ $( $SMI -i $MY_DEVICE --query-gpu=name --format=csv,noheader | grep -E 'CMP6-1|P106-100|1050') ]]; then
									# Graphics clock
									${NVD} -a "[gpu:$MY_DEVICE]/GPUGraphicsClockOffset[2]=$(get_c)"
									# Memory clock
									${NVD} -a "[gpu:$MY_DEVICE]/GPUMemoryTransferRateOffset[2]=$(get_m)"

								elif [[ $( $SMI -i $MY_DEVICE --query-gpu=name --format=csv,noheader | grep -E 'CMP4-1|P104-100') ]]; then
									# Graphics clock
									${NVD} -a "[gpu:$MY_DEVICE]/GPUGraphicsClockOffset[1]=$(get_c)"
									# Memory clock
									${NVD} -a "[gpu:$MY_DEVICE]/GPUMemoryTransferRateOffset[1]=$(get_m)"

								else
									# Graphics clock
									${NVD} -a "[gpu:$MY_DEVICE]/GPUGraphicsClockOffset[3]=$(get_c)"
									# Memory clock
									${NVD} -a "[gpu:$MY_DEVICE]/GPUMemoryTransferRateOffset[3]=$(get_m)"
								fi

        fi
 done
fi

echo
echo "Done"
echo
