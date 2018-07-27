#!/bin/bash

# Watchdog for Cyclenerd/ethereum_nvidia_miner based on nvOC v0019-2.0 - Community Release by papampi, Stubo and leenoox
# https://github.com/papampi/nvOC_by_fullzero_Community_Release/blob/19.2/5watchdog

echo "Watchdog ver 1.2"

# Set higher process and disk I/O priorities because we are essential service
#sudo renice -n -15 -p $$ && sudo ionice -c2 -n0 -p$$ >/dev/null 2>&1
#sleep 1

# Load global settings settings.conf
if ! source ~/settings.conf; then
	echo "FAILURE: Cannot load global settings 'settings.conf'"
	exit 9
fi

export DISPLAY=:0

# Global Variables
THRESHOLD=80         # Minimum allowed % utilization before taking action

# Set higher process and disk I/O priorities because we are essential service
sudo renice -n -19 -p $$ >/dev/null 2>&1 && sudo ionice -c2 -n0 -p$$ >/dev/null 2>&1
sleep 1

# Initialize vars
REBOOTRESET=0
GPU_COUNT=$(nvidia-smi -i 0 --query-gpu=count --format=csv,noheader,nounits)
COUNT=$((6 * $GPU_COUNT))
# Track how many times we have restarted the Miner
RESTART=0
ALERT=""
LOST_GPU_ALERT="$(date) - Lost GPU so restarting system. Found GPU's:
$(nvidia-smi --query-gpu=gpu_bus_id --format=csv)
$(date) - reboot in 10 seconds"
LF=$'\n'

# Dynamic sleep time, dstm zm miner takes a very long time to load GPUs
SLEEP_TIME=$((($GPU_COUNT * 10 ) + 10 ))
numtest='^[0-9.]+$'

# Check if Miner is running
if [[ -z $(ps ax | grep -i screen | grep miner) ]]
then
  echo "WARNING: $(date) - Miner is not running, starting watchdog in 10 seconds to look for problems"
else
  echo "$(date) - Miner is running, waiting $SLEEP_TIME seconds before going 'on watch'"
  sleep $SLEEP_TIME
fi



# Main Loop [infinite]
while true; do

  # Echo status
  UTILIZATIONS=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)
  echo "GPU UTILIZATION: " $UTILIZATIONS
  echo "      GPU_COUNT: " $GPU_COUNT
  echo " "

  # Set/increment vars
  NUM_GPU_BLW_THRSHLD=0              # Track how many GPU are below threshold
  REBOOTRESET=$(($REBOOTRESET + 1))

  # Loop over each GPU and check utilization
  for ((GPU=0;GPU < $GPU_COUNT;GPU++)); do
    { IFS=', ' read UTIL CURRENT_TEMP CURRENT_FAN PWRLIMIT POWERDRAW ; } < <(nvidia-smi -i $GPU --query-gpu=utilization.gpu,temperature.gpu,fan.speed,power.limit,power.draw --format=csv,noheader,nounits)

    # Numeric check: if any are not numeric, we have a mining problem

    # Workaround for 1050's reporting "[Not Supported]" or "[Unknown Error]" when power.draw is queried from nvidia-smi
    if [[ $(nvidia-smi -i $GPU --query-gpu=name --format=csv,noheader,nounits | grep "1050") ]]; then
      if ! [[ ( $UTIL =~ $numtest ) && ( $CURRENT_TEMP =~ $numtest ) && ( $CURRENT_FAN =~ $numtest ) && ( $PWRLIMIT =~ $numtest ) ]]; then
        # Not numeric so: Help we've lost a GPU, so reboot
	LOST_GPU_INFO="Gpu: $GPU, Util: $UTIL, Temp: $CURRENT_TEMP, Fan: $CURRENT_FAN, Power: $POWERDRAW, Power limit: $PWRLIMIT."
	echo "${LOST_GPU_ALERT}${LF}${LOST_GPU_INFO}"
        if [[ $TELEGRAM_ALERTS == "YES" ]]; then
          bash ~/telegram.sh "${LOST_GPU_ALERT}${LF}${LOST_GPU_INFO}"
        fi
        sleep 10
        sudo reboot
      elif [ $UTIL -lt $THRESHOLD ] # If utilization is lower than threshold, decrement counter
      then
        logger -s echo "$(date) - GPU $GPU under threshold found - GPU UTILIZATION:  " $UTIL
        COUNT=$(($COUNT - 1))
        NUM_GPU_BLW_THRSHLD=$(($NUM_GPU_BLW_THRSHLD + 1))
      fi
    else
      if ! [[ ( $UTIL =~ $numtest ) && ( $CURRENT_TEMP =~ $numtest ) && ( $CURRENT_FAN =~ $numtest ) && ( $POWERDRAW =~ $numtest ) && ( $PWRLIMIT =~ $numtest ) ]]; then
        # Not numeric so: Help we've lost a GPU, so reboot
	LOST_GPU_INFO="Gpu: $GPU, Util: $UTIL, Temp: $CURRENT_TEMP, Fan: $CURRENT_FAN, Power: $POWERDRAW, Power limit: $PWRLIMIT."
	logger -s "${LOST_GPU_ALERT}${LF}${LOST_GPU_INFO}"
        if [[ $TELEGRAM_ALERTS == "YES" ]]; then
          bash ~/telegram.sh "${LOST_GPU_ALERT}${LF}${LOST_GPU_INFO}"
        fi
        sleep 10
        sudo reboot
      elif [ $UTIL -lt $THRESHOLD ] # If utilization is lower than threshold, decrement counter
      then
	logger -s "$(date) - GPU $GPU under threshold found - GPU UTILIZATION:  {$UTIL}"
        COUNT=$(($COUNT - 1))
        NUM_GPU_BLW_THRSHLD=$(($NUM_GPU_BLW_THRSHLD + 1))
      fi
    fi
    sleep 0.2    # 0.2 seconds delay until querying the next GPU
  done

  # If we found at least one GPU below the utilization threshold
  if [ $NUM_GPU_BLW_THRSHLD -gt 0 ]
  then
    logger "$(date) - Debug: NUM_GPU_BLW_THRSHLD=$NUM_GPU_BLW_THRSHLD, COUNT=$COUNT, RESTART=$RESTART, REBOOTRESET=$REBOOTRESET"

    # Check for Internet and wait if down
    if ! nc -vzw1 google.com 443;
    then
      logger -s "WARNING: $(date) - Internet is down, checking..."
    fi
    while ! nc -vzw1 google.com 443;
    do
      logger -s "WARNING: $(date) - Internet is down, checking again in 30 seconds..."
      sleep 30
      NET_CHECK_COUNT=$(($NET_CHECK_COUNT + 1)) # count loop times
      # When we come out of the loop, reset to skip additional checks until the next time through the loop
      if nc -vzw1 google.com 443;
      then
	logger -s "$(date) - Internet was down, Now it's ok"
	if [[ $TELEGRAM_ALERTS == "YES" ]]; then
	    bash ~/telegram.sh "$(date) - Internet was down, Now it's ok"
	fi
        REBOOTRESET=0; RESTART=0; COUNT=$((6 * $GPU_COUNT))
        #### Now that internet comes up check and restart miner if needed, no need to restart Miner, problem was the internet.
    	if [[ -z $(ps ax | grep -i screen | grep miner) ]]
        then
	  logger -s "$(date) - miner is not running, start miner"
	  # Kill autotempfan just in case
	  target_temp=$(ps ax | grep -i screen | grep autotempfan | awk '{print $1}')
	  kill $target_temp
	  # Start Miner
	  bash ~/miner.sh
	  #wait for miner to start hashing
	  sleep $SLEEP_TIME
	else
	  echo "$(date) - miner is running, waiting $SLEEP_TIME seconds before going 'on watch'"
	  sleep $SLEEP_TIME
	fi
    fi
    if [[ $NET_CHECK_COUNT -gt 3 ]]; then
	# Let's try to restart network!
	logger -s "ALERT: $(date) - Internet is down and will try to recover restarting network services..."
	sudo systemctl restart networking.service
    fi
 done
 
# Look for no miner screen and get right to miner restart
if [[ $(ps ax | grep -i screen | grep miner | wc -l) -eq 0 ]]
   then
   COUNT=0
   logger -s "WARNING: $(date) - Found no miner, jumping to Miner restart"
fi

    # Percent of GPUs below threshold
    PCT_GPU_BAD=$((100 * NUM_GPU_BLW_THRSHLD / GPU_COUNT ))

    #  If we have had too many GPU below threshold over time OR
    #     we have ALL GPUs below threshold AND had at least (#GPUs + 1)
    #        occurrences of below threshold (2nd run through the loop
    #        to allow miner to fix itself)
    if [[ $COUNT -le 0 || ($PCT_GPU_BAD -eq 100 && $COUNT -lt $((5 * $GPU_COUNT))) ]]
    then
      # Get some some diagnostics to the logs before restarting or rebooting
      logger -s "WARNING: $(date) - Problem found: See diagnostics below: "
      logger -s "Percent of GPUs bellow threshold: $PCT_GPU_BAD %"
      logger -s "$(nvidia-smi --query-gpu=name,pstate,temperature.gpu,fan.speed,utilization.gpu,power.draw,power.limit --format=csv)"
			echo ""
      # If we have had 4 miner restarts and still have low utilization
      if [[ $RESTART -gt 4 ]]
      then
        ALERT="CRITICAL: $(date) - Utilization is too low: reviving did not work so restarting system in 10 seconds"
	logger -s "${ALERT}"
	echo ""
        if [[ $TELEGRAM_ALERTS == "YES" ]]; then
          bash ~/telegram.sh "${ALERT}"
        fi
        sleep 10
        sudo reboot
      fi

      # Kill the miner to be sure it's gone
      if [[ $(ps ax | grep -i screen | grep miner) ]]
      then
	target_miner=$(ps ax | grep -i screen | grep miner | awk '{print $1}')
	kill $target_miner
     fi

      echo ""
      ALERT="CRITICAL: $(date) - GPU Utilization is too low: restarting Miner..."
      logger -s "${ALERT}"

      if [[ $TELEGRAM_ALERTS == "YES" ]]; then
        bash ~/telegram.sh "${ALERT}"
      fi

      if [[ $(ps ax | grep -i screen | grep autotempfan) ]]
      then
	target_temp=$(ps ax | grep -i screen | grep autotempfan | awk '{print $1}')
	kill $target_temp
      fi

      # Restart everything
      bash ~/miner.sh

      RESTART=$(($RESTART + 1))
      REBOOTRESET=0
      COUNT=$GPU_COUNT

      # Give Miner time to restart to prevent reboot
      sleep $SLEEP_TIME
      ALERT="$(date) - Back 'on watch' after miner restart"
	logger -s "${ALERT}"
	if [[ $TELEGRAM_ALERTS == "YES" ]]; then
        bash ~/telegram.sh "${ALERT}"
      fi
    	else
      	logger -s "$(date) - Low Utilization Detected: Miner will reinit if there are $COUNT consecutive failures"
      	echo ""
    	fi
    	# No below threshold GPUs detected for this pass
  	else
    # All is good, reset the counter
    COUNT=$((6 * $GPU_COUNT))
    echo "$(date) - No mining issues detected."

    # No need for a reboot after 5 times through the main loop with no issues
    if [ $REBOOTRESET -gt 5 ]
    then
      RESTART=0
      REBOOTRESET=0
    fi
  fi
  # Delay until next cycle
 sleep 10
done
