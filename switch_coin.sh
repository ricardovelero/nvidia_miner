#!/bin/bash

if [[ ! -z "$1" ]] || [[ $1 = *[ETHETCBTG]* ]]; then
  sed -i.bak '/COIN/d' ~/settings.conf
  echo >> ~/settings.conf
  echo 'COIN="$1"' >> ~/settings.conf
  sudo restart
else
  echo "You need to specify the correct coin type (ETH, ETC, BTG) to switch to. The current is: $(cat ~/settings.conf | grep 'COIN')"
fi
