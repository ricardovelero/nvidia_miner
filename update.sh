#!/usr/bin/env bash

#
# update.sh
#
# Update files from https://github.com/ricardovelero/nvidia_miner
#

cd ~prospector || exit 9

echo; echo "Update '.bashrc' and '.bash_aliases'"
curl -f "https://raw.githubusercontent.com/ricardovelero/nvidia_miner/master/.bashrc" -o .bashrc
curl -f "https://raw.githubusercontent.com/ricardovelero/nvidia_miner/master/.bash_aliases" -o .bash_aliases

echo; echo "Update '.screenrc'"
curl -f "https://raw.githubusercontent.com/ricardovelero/nvidia_miner/master/.screenrc" -o .screenrc

echo; echo "Update 'setup.sh'"
curl -f "https://raw.githubusercontent.com/ricardovelero/nvidia_miner/master/setup.sh" -o setup.sh

echo; echo "Update 'miner.sh'"
curl -f "https://raw.githubusercontent.com/ricardovelero/nvidia_miner/master/miner.sh" -o miner.sh

echo; echo "Update 'nvidia-overclock.sh'"
curl -f "https://raw.githubusercontent.com/ricardovelero/nvidia_miner/master/nvidia-overclock.sh" -o nvidia-overclock.sh
chmod 755 nvidia-overclock.sh

echo; echo "Update 'myip.sh'"
curl -f "https://raw.githubusercontent.com/ricardovelero/nvidia_miner/master/myip.sh" -o myip.sh
chmod 755 myip.sh

echo; echo "Update 'autotempfan.sh'"
curl -f "https://raw.githubusercontent.com/ricardovelero/nvidia_miner/master/autotempfan.sh" -o autotempfan.sh
chmod 755 autotempfan.sh

echo; echo "Update 'watchdog.sh'"
curl -f "https://raw.githubusercontent.com/ricardovelero/nvidia_miner/master/watchdog.sh" -o watchdog.sh
chmod 755 watchdog.sh

echo; echo "Update 'gpuinfo.sh'"
curl -f "https://raw.githubusercontent.com/ricardovelero/nvidia_miner/master/gpuinfo.sh" -o gpuinfo.sh
chmod 755 gpuinfo.sh

echo; echo "Update 'telegram.sh'"
curl -f "https://raw.githubusercontent.com/ricardovelero/nvidia_miner/master/telegram.sh" -o telegram.sh
chmod 755 telegram.sh

# echo; echo "Update 'net_wdog.sh'"
# curl -f "https://raw.githubusercontent.com/ricardovelero/nvidia_miner/master/net_wdog.sh" -o net_wdog.sh
# chmod 755 net_wdog.sh

#echo; echo "Backing up Settings to settings.conf.bak and Update 'settings.conf'"
#cp settings.conf settings.conf.bak
#curl -f "https://raw.githubusercontent.com/ricardovelero/nvidia_miner/master/settings.conf" -o settings.conf

echo; echo "Update 'update.sh'"
curl -f "https://raw.githubusercontent.com/ricardovelero/nvidia_miner/master/update.sh" -o update.sh
chmod 755 update.sh

sleep 2

echo; echo "Checking Ethminer directory"
if [[ ! -d /home/prospector/ethminer/legacy/ ]]; then
  echo "Making legacy Ethminer directory"
  mkdir -p /home/prospector/ethminer/legacy
fi
if [[ ! -d /home/prospector/ethminer/latest/ ]]; then
  echo "Making Ethminer directory"
  mkdir -p /home/prospector/ethminer/latest
else
  echo "Ethminer directory structure already fixed"
fi

echo; echo "Checking for Ethminer 0.16"

if [[ ! $(/home/prospector/ethminer/latest/ethminer --version | grep 0.16) ]]
then
  echo "Moving old Ethminer to legacy directory"
  cp /home/prospector/ethminer/latest/ethminer /home/prospector/ethminer/legacy/ethminer
  echo "Downloading and making changes for Ethminer 0.16"
  mkdir -p /home/prospector/ethminer/latest
  wget https://github.com/ricardovelero/nvidia_miner/blob/master/ethminer/latest/ethminer?raw=true -O ~/ethminer/latest/ethminer
  chmod 755 /home/prospector/ethminer/latest/ethminer
else
  echo "Latest ethminer already downloaded"
fi

echo; echo "Checking Funakoshi directory"
if [[ ! -d /home/prospector/funakoshi/legacy/ ]]; then
  echo "Making legacy Funakoshi directory"
  mkdir -p /home/prospector/funakoshi/legacy
fi
if [[ ! -d /home/prospector/funakoshi/latest/ ]]; then
  echo "Making Ethminer directory"
  mkdir -p /home/prospector/funakoshi/latest
else
  echo "Funakoshi directory structure already fixed"
fi

echo; echo "Checking for Funakoshi Miner 4.6"

if [[ ! $(/home/prospector/funakoshi/latest/funakoshiMiner --version | grep 4.6) ]]
then
  echo "Moving old funakoshiMiner to legacy directory"
  cp /home/prospector/funakoshi/latest/funakoshiMiner /home/prospector/funakoshi/legacy/funakoshiMiner
  cp /home/prospector/funakoshi/latest/Start.sh /home/prospector/funakoshi/legacy/Start.sh
  echo "Downloading and making changes for Funakoshi 4.6"
  mkdir -p /home/prospector/funakoshi/latest
  wget https://github.com/ricardovelero/nvidia_miner/blob/master/funakoshi/latest/funakoshiMiner?raw=true -O ~/funakoshi/latest/funakoshiMiner
  wget https://github.com/ricardovelero/nvidia_miner/blob/master/funakoshi/latest/Start.sh?raw=true -O ~/funakoshi/latest/Start.sh
  chmod 755 /home/prospector/funakoshi/latest/funakoshiMiner
  chmod 755 /home/prospector/funakoshi/latest/Start.sh
else
  echo "Latest funakoshi already downloaded"
fi

sleep 2

echo; echo "Crontab setup"
echo "Resetting Crontab"
crontab -r

croncmd_miner="sleep 60 && bash ~/miner.sh"
croncmd_greet='sleep 80 && bash ~/telegram.sh "Miner starting" >/dev/null 2>&1'
croncmd_nvioc="sleep 150 && bash ~/nvidia-overclock.sh >/dev/null 2>&1"
croncmd_netwd="sudo dhclient >/dev/null 2>&1"
croncmd_repor="bash ~/telegram.sh >/dev/null 2>&1"

cronjob_at_reboot="@reboot"
cronjob_atfifteen="15 * * * *"
cronjob_atonehour="0 */1 * * *"
cronjob_atsixhour="#0 */6 * * *"
cronjob_attwelveh="#0 */6 * * *"

echo "Adding new scheduled commands:"

echo "Start miner after 60 seconds of reboot"
( crontab -l | grep -v -F "$croncmd_miner" ; echo "$cronjob_at_reboot $croncmd_miner" ) | crontab -

echo "Send a telegram message after 80 seconds reboot"
( crontab -l | grep -v -F "$croncmd_greet" ; echo "$cronjob_at_reboot $croncmd_greet" ) | crontab -

echo "After 2.5 minutes uptime, 'nvidia-overclock.sh' starts"
( crontab -l | grep -v -F "$croncmd_nvioc" ; echo "$cronjob_at_reboot $croncmd_nvioc" ) | crontab -

echo "Schedule 'dhclient' to run every 12 hours"
( crontab -l | grep -v -F "$croncmd_netwd" ; echo "$cronjob_attwelveh $croncmd_netwd" ) | crontab -

echo "Telegram report every 6 hours"
( crontab -l | grep -v -F "$croncmd_repor" ; echo "$cronjob_atsixhour $croncmd_repor" ) | crontab -

sleep 2

echo; echo; echo "Installing needed packages"
sudo -- sh -c 'sudo apt install -y bc mc moreutils gawk'

echo
echo "Done"
echo
