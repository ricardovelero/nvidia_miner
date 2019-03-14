#!/bin/bash

# Temp control for Cyclenerd/ethereum_nvidia_miner based on TEMP_CONTROL for nvOC v0019-2.0 by leenoox
# https://github.com/papampi/nvOC_by_fullzero_Community_Release/blob/19.2/6tempcontrol

echo "Automatic Temp Control"

# Set higher process and disk I/O priorities because we are essential service
sudo renice -n -15 -p $$ && sudo ionice -c2 -n0 -p$$ >/dev/null 2>&1
sleep 1

# Load global settings settings.conf
if ! source ~/settings.conf; then
	echo "FAILURE: Cannot load global settings 'settings.conf'"
	exit 9
fi

export DISPLAY=:0

NVD="sudo DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0 nvidia-settings"
SMI="sudo nvidia-smi"

# Determine the number of available GPU's
GPUS=$(nvidia-smi -i 0 --query-gpu=count --format=csv,noheader,nounits)

echo -e "Detected: $GPUS GPU's"
echo ""
count=0


# Dynamic variables creation - assign variables for the available GPU's only
# Set variables for Temp and Power Limit; Enable fan control; Display info
while [ $count -lt $GPUS ]; do

  if [ $INDIVIDUAL_POWERLIMIT == "YES" ]; then
    POWER_LIMIT[$count]=$(( INDIVIDUAL_POWERLIMIT_$count ))
  elif [ $INDIVIDUAL_POWERLIMIT == "NO" ]; then
    POWER_LIMIT[$count]=$POWERLIMIT_WATTS
  fi

  if [ $INDIVIDUAL_TARGET_TEMPS == "YES" ]; then
    TARGET_TEMP[$count]=$(( TARGET_TEMP_$count ))
  elif [ $INDIVIDUAL_TARGET_TEMPS == "NO" ]; then
    TARGET_TEMP[$count]=$TARGET_TEMP
  fi

  # Info - display assigned values per GPU
  echo -e "$GPU $count:  POWER LIMIT: ${POWER_LIMIT[$count]},  TARGET TEMP: ${TARGET_TEMP[$count]}"

  # Enable fan control
  ${NVD} -a [gpu:${count}]/GPUFanControlState=1 >/dev/null 2>&1
  sleep 0.1

  (( count++ ))

done

FAN_ADJUST=$__FAN_ADJUST

# If user sets the fan speed too low in 1bash, override and set it to 30%
if [ $MINIMAL_FAN_SPEED -lt 30 ]; then
  MINIMAL_FAN_SPEED=30
fi

echo ""
# Info - display the Global settings
echo -e "$GLOBAL  FAN_ADJUST (%):  $FAN_ADJUST${N}"
echo -e "$GLOBAL  POWER_ADJUST (W):  $POWER_ADJUST${N}"
echo -e "$GLOBAL  ALLOWED_TEMP_DIFF (C):  $ALLOWED_TEMP_DIFF${N}"
echo -e "$GLOBAL  RESTORE_POWER_LIMIT (%):  $RESTORE_POWER_LIMIT${N}"
echo -e "$GLOBAL  MINIMAL_FAN_SPEED (%):  $MINIMAL_FAN_SPEED${N}"
echo ""

# How often should TEMP_CONTROL check and adjust the fans
# Allowed value between 15 and 30 seconds (IMO, 20 seconds works well)
LOOP_TIMER_SLEEP=20

if [ "$LOOP_TIMER_SLEEP" -lt "15" ]; then
  LOOP_TIMER_SLEEP=15
elif [ "$LOOP_TIMER_SLEEP" -gt "30" ]; then
  LOOP_TIMER_SLEEP=30
fi

# Calculating the main timer dependant on the number of GPU's because
# we are adding 0.5 seconds delay between every GPU check so that
# we don't overload nvidia API (previously the API was spammed, especialy on
# systems with 13+ GPU's causing slight delay for the miner. This has reduced stale shares for me)
LOOP_TIMER=$(echo "$LOOP_TIMER_SLEEP - ( $GPUS * 0.5 )" | bc )

# When API returns error message due to frozen/hung GPU, the original Temp Control script
# was breaking with error because it was expecting numeric but received a text value, leaving
# the system without temp control and potential to damage GPU's.
# Adding numtest check to the returned values from nvidia-smi to prevent such occurance
numtest='^[0-9.]+$'

# Time in seconds before we reboot should we detect error and watchdog didn't react
ERR_TIMER=60
ERR_TIMER_BRK=$ERR_TIMER

# The Main Loop
while true; do
  GPU=0
  while [ $GPU -lt $GPUS ]; do
    { IFS=', ' read CURRENT_TEMP CURRENT_FAN PWRLIMIT POWERDRAW; } < <(nvidia-smi -i $GPU --query-gpu=temperature.gpu,fan.speed,power.limit,power.draw --format=csv,noheader,nounits)

    # Numeric check to avoid script breakage should nvidia-smi return error, also acts as backup watchdog

    # Workaround for 1050's reporting "[Not Supported]" or "[Unknown Error]" when power.draw is queried from nvidia-smi
    if [[ $(nvidia-smi -i $GPU --query-gpu=name --format=csv,noheader,nounits | grep "1050") ]]; then
      if ! [[ ( $CURRENT_TEMP =~ $numtest ) && ( $CURRENT_FAN =~ $numtest ) && ( $PWRLIMIT =~ $numtest ) ]]; then
        # Non numeric value! Problem detected! Give watchdog 60 seconds to react, if not, assume watchdog froze - we will reboot in 60 sec (backup watchdog function)
        while [ $ERR_TIMER -gt 0 ]; do
          echo -e "WARNING: $(date) - Problem detected! GPU$GPU is not responding. Will give watchdog $ERR_TIMER seconds to react, if not we will reboot!" | tee -a ${LOG_FILE}
          if [[ $TELEGRAM_ALERTS == "YES" ]]; then
            bash ~/telegram.sh "Problem detected! GPU$GPU is not responding. Will give watchdog $ERR_TIMER seconds to react, if not we will reboot!"
          fi
          sleep 15
          { IFS=', ' read CURRENT_TEMP CURRENT_FAN PWRLIMIT; } < <(nvidia-smi -i $GPU --query-gpu=temperature.gpu,fan.speed,power.limit --format=csv,noheader,nounits)
          if ! [[ ( $CURRENT_TEMP =~ $numtest ) && ( $CURRENT_FAN =~ $numtest ) && ( $PWRLIMIT =~ $numtest ) ]]; then
            ERR_TIMER=$(($ERR_TIMER - 15))
          else
            ERR_TIMER=$ERR_TIMER_BRK
            break
          fi
          if [ $ERR_TIMER -le 0 ]; then
            echo -e "WARNING: $(date) - Problem detected with GPU$GPU. Watchdog didn't react. System will reboot by the TEMP_CONTROL to correct the problem!" | tee -a ${LOG_FILE} ${WD_LOG_FILE}
            if [[ $TELEGRAM_ALERTS == "YES" ]]; then
              bash ~/telegram.sh "Problem detected with GPU$GPU. Watchdog didnt react. System will reboot by the TEMP_CONTROL to correct the problem!"
            fi
            sleep 3
            sudo reboot
          fi
        done
      fi
    else
      if ! [[ ( $CURRENT_TEMP =~ $numtest ) && ( $CURRENT_FAN =~ $numtest ) && ( $POWERDRAW =~ $numtest ) && ( $PWRLIMIT =~ $numtest ) ]]; then
        # Non numeric value! Problem detected! Give watchdog 60 seconds to react, if not, assume watchdog froze - we will reboot in 60 sec (backup watchdog function)
        while [ $ERR_TIMER -gt 0 ]; do
          echo -e "WARNING: $(date) - Problem detected! GPU$GPU is not responding. Will give watchdog $ERR_TIMER seconds to react, if not we will reboot!" | tee -a ${LOG_FILE}
          if [[ $TELEGRAM_ALERTS == "YES" ]]; then
            bash ~/telegram.sh "Problem detected! GPU$GPU is not responding. Will give watchdog $ERR_TIMER seconds to react, if not we will reboot!"
          fi
          sleep 15
          { IFS=', ' read CURRENT_TEMP CURRENT_FAN PWRLIMIT POWERDRAW; } < <(nvidia-smi -i $GPU --query-gpu=temperature.gpu,fan.speed,power.limit,power.draw --format=csv,noheader,nounits)
          if ! [[ ( $CURRENT_TEMP =~ $numtest ) && ( $CURRENT_FAN =~ $numtest ) && ( $POWERDRAW =~ $numtest ) && ( $PWRLIMIT =~ $numtest ) ]]; then
            ERR_TIMER=$(($ERR_TIMER - 15))
          else
            ERR_TIMER=$ERR_TIMER_BRK
            break
          fi
          if [ $ERR_TIMER -le 0 ]; then
            echo -e "WARNING: $(date) - Problem detected with GPU$GPU. Watchdog didn't react. System will reboot by the TEMP_CONTROL to correct the problem!" | tee -a ${LOG_FILE} ${WD_LOG_FILE}
            if [[ $TELEGRAM_ALERTS == "YES" ]]; then
              bash ~/telegram.sh "Problem detected with GPU$GPU. Watchdog didnt react. System will reboot by the TEMP_CONTROL to correct the problem!"
            fi
            sleep 3
            sudo reboot
          fi
        done
      fi
    fi

    POWERLIMIT=${PWRLIMIT%%.*}
    TEMP_DIFF=$((${TARGET_TEMP[${GPU}]} - $CURRENT_TEMP))
    NEW_FAN_SPEED=$CURRENT_FAN

    echo -e "${B}GPU $GPU${N}, Target temp: ${B}${TARGET_TEMP[${GPU}]}${N}, Current: ${B}$CURRENT_TEMP${N}, Diff: ${B}$TEMP_DIFF${N}, Fan: ${B}$CURRENT_FAN${N}, Power: ${B}$POWERDRAW${N}"
    echo ""

    if [ "$CURRENT_TEMP" -gt "${TARGET_TEMP[${GPU}]}" ]; then
      # This can be far more advanced. For now if difference is more than 5 C multiply adjustement by 2
      if [ $TEMP_DIFF -lt "-5" ]; then
        FAN_ADJUST_CALCULATED=$(($FAN_ADJUST * 2))
      else
        FAN_ADJUST_CALCULATED=$FAN_ADJUST
      fi
      NEW_FAN_SPEED=$(($CURRENT_FAN + $FAN_ADJUST_CALCULATED))
      if [ $NEW_FAN_SPEED -gt 100 ]; then
        NEW_FAN_SPEED=100
        # Fan speed was already (very close to) 100, we have to drop the power limit a bit
        echo -e "WARNING: GPU $GPU, $(date) - Fan speed was already close to max, dropping Power Limit in order to maintain the desired temp" | tee -a ${LOG_FILE}
        if [[ $TELEGRAM_ALERTS == "YES" ]]; then
          bash ~/telegram.sh "WARNING: GPU $GPU, $(date) - Fan speed was already close to max, dropping Power Limit in order to maintain the desired temp"
        fi
        NEW_POWER_LIMIT=$(($POWERLIMIT - $POWER_ADJUST))
        echo -e "${B}WARNING: GPU $GPU${N}, ${R}$(date) - Adjusting Power Limit for ${B}GPU$GPU${N}${R}. Old Limit: ${B}$POWERLIMIT${N}${R} New Limit: ${B}$NEW_POWER_LIMIT${N}${R} Fan speed: ${B}$NEW_FAN_SPEED${N}" | tee -a ${LOG_FILE}
        echo ""
        ${SMI} -i $GPU -pl ${NEW_POWER_LIMIT}
      fi
    else
      # Current temp is lower than target, so we can relax fan speed, and restore original power limit if applicable
      if [ $TEMP_DIFF -gt $ALLOWED_TEMP_DIFF ]; then
        # This can be far more advanced too
        NEW_FAN_SPEED=$(($CURRENT_FAN - $FAN_ADJUST))
        # Set to minimal fan speed if calculated is below
        if [ $NEW_FAN_SPEED -lt $MINIMAL_FAN_SPEED ]; then
          NEW_FAN_SPEED=$MINIMAL_FAN_SPEED
        fi
        # Restore original power limit when possible using fan speed
        if [ ${POWER_LIMIT[${GPU}]} -ne $POWERLIMIT ]; then
          if [ $NEW_FAN_SPEED -lt $RESTORE_POWER_LIMIT ]; then
            NEW_POWER_LIMIT=${POWER_LIMIT[${GPU}]}
            echo -e "GPU$GPU${N}${C}$(date) - Restoring Power Limit for ${N}${B}GPU$GPU${N}. ${C}Old limit: ${N}${B}$POWERLIMIT${N}${C} New limit: ${N}${B}$NEW_POWER_LIMIT${N}${C} Fan speed: ${N}${B}$NEW_FAN_SPEED${N}"
            echo ""
            ${SMI} -i $GPU -pl ${NEW_POWER_LIMIT}
          fi
        fi
      fi
    fi

    if [ "$NEW_FAN_SPEED" -ne "$CURRENT_FAN" ]; then
      echo -e "GPU $GPU, $(date) - Adjusting fan from: $CURRENT_FAN to: $NEW_FAN_SPEED Temp: $CURRENT_TEMP"
      echo ""
      ${NVD} -a [fan:${GPU}]/GPUTargetFanSpeed=${NEW_FAN_SPEED} 2>&1 >/dev/null
    fi

    (( GPU++ ))
    sleep 0.5    # 0.5 seconds delay until querying the next GPU
  done
  echo "$(date) - All good, will check again in $LOOP_TIMER seconds"
  echo ""
  echo ""
  echo ""
  sleep $LOOP_TIMER
done
