#!/bin/bash

if [[ ! -z "$1" ]]; then
  sed -i.bak '/COIN/d' ~/settings.conf
  echo >> ~/settings.conf
  echo 'COIN="$1"' >> ~/settings.conf
  sudo restart
else
  CURRENT_COIN=$(cat ~/settings.conf | grep "COIN")
  echo "You need to specify the coin type (ETH, ETC, BTG) to switch to. The current is: $CURRENT_COIN"
fi
