#!/usr/bin/env bash

#
# setup_cron.sh
#
# Setup system crontab for miner
#

echo 'Adding telegram "Miner starting"'
croncmd='bash ~/telegram.sh "Miner starting" >/dev/null 2>&1'
cronjob='@reboot sleep 80 && $croncmd'

( crontab -l | grep -v -F "$croncmd" ; echo "$cronjob" ) | crontab -

echo 'Adding telegram report every 6 hours'
croncmd='bash ~/telegram.sh >/dev/null 2>&1'
cronjob='0 */6 * * * $croncmd'
