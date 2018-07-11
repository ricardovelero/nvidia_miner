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

echo; echo "Update 'net_wdog.sh'"
curl -f "https://raw.githubusercontent.com/ricardovelero/nvidia_miner/master/net_wdog.sh" -o net_wdog.sh
chmod 755 net_wdog.sh

echo; echo "Backing up Settings to settings.conf.bak and Update 'settings.conf'"
cp settings.conf settings.conf.bak
curl -f "https://raw.githubusercontent.com/ricardovelero/nvidia_miner/master/settings.conf" -o settings.conf

echo; echo "Update 'update.sh'"
curl -f "https://raw.githubusercontent.com/ricardovelero/nvidia_miner/master/update.sh" -o update.sh
chmod 755 update.sh

echo "Checking Ethminer directory"
if [[ ! -d /home/prospector/ethminer/latest/ ]]
then
  echo "Making Ethminer directory"
  mkdir -p /home/prospector/ethminer/latest
else
  echo "Ethminer directory structure already fixed"
fi

echo "Checking for Ethminer 0.13"

if [[ ! $(/home/prospector/ethminer/latest/ethminer --version | grep 0.13) ]]
then
  echo "Downloading and making changes for Ethminer 0.13"
  mkdir -p /home/prospector/ethminer/latest
  curl -f "https://solucionesio.es/0.13/ethminer" -o /home/prospector/ethminer/latest/ethminer
  chmod 755 /home/prospector/ethminer/latest/ethminer
else
  echo "Ethminer 0.13 already downloaded"
fi

echo; echo "Crontab setup"
echo "Resetting Crontab"
crontab -r

croncmd_miner="sleep 60 && bash ~/miner.sh"
croncmd_greet='sleep 80 && bash ~/telegram.sh "Miner starting" >/dev/null 2>&1'
croncmd_nvioc="sleep 150 && bash ~/nvidia-overclock.sh >/dev/null 2>&1"
croncmd_netwd="bash ~/net_wdog.sh >/dev/null 2>&1"
croncmd_repor="bash ~/telegram.sh >/dev/null 2>&1"

cronjob_at_reboot="@reboot"
cronjob_atfifteen="15 * * * *"
cronjob_atsixhour="#0 */6 * * *"

echo "Adding new scheduled commands:"

echo "Start miner after 60 seconds of reboot"
( crontab -l | grep -v -F "$croncmd_miner" ; echo "$cronjob_at_reboot $croncmd_miner" ) | crontab -

echo "Send a telegram message after 80 seconds reboot"
( crontab -l | grep -v -F "$croncmd_greet" ; echo "$cronjob_at_reboot $croncmd_greet" ) | crontab -

echo "After 2.5 minutes uptime, 'nvidia-overclock.sh' starts"
( crontab -l | grep -v -F "$croncmd_nvioc" ; echo "$cronjob_at_reboot $croncmd_nvioc" ) | crontab -

echo "Schedule network watchdog 'net_wdog.sh' to run every 15 minutes"
( crontab -l | grep -v -F "$croncmd_netwd" ; echo "$cronjob_atfifteen $croncmd_netwd" ) | crontab -

echo "Telegram report every 6 hours"
( crontab -l | grep -v -F "$croncmd_repor" ; echo "$cronjob_atsixhour $croncmd_repor" ) | crontab -

echo; echo; echo "Updating and Upgrading system packages and installing needed packages"
sudo -- sh -c 'apt update; apt upgrade -y; apt autoremove -y; apt autoclean -y; sudo apt install -y bc mc moreutils gawk'

echo
echo "Done"
echo
