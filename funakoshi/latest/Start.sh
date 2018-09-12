#!/bin/bash
echo "############################################"
echo "Please change your pool and account options."
echo "############################################"

./funakoshiMiner -l btg.suprnova.cc:8817 -u gahbnhij.w1

# Usage:
#  ./funakoshiMiner -l pool_domain[:optional_port_number] -u user_name
#                      [-p password] [options]...
# 
#  Stratum Options:
#     -l               Stratum server domain-name plus optional port-number
#                        (separated by colon ':' from domain)
#     --server         Synonym to -l (without the port-number)
#     --port           The optional port number (without the colon)
#     -u               Account-name in pool or wallet address (some pools
#                        require account-name other require wallet-address)
#     --user           Synonym to -u
#     -p               Worker password (not required)
#     --pass           Synonym to -p
# 
#  Other Options:
#     -f fileName      Name of log-file. When specified will contain a copy
#                        of the log-info that is written to console
#     -tele-port p     Activating HTTP telemetry + listening on port 127.0.0.1:p
#     -cd 0 1 2 ...    Selecting which CUDA-Devices (GPUs) to use
#                        starting from 0. The default when -cd argument is
#                        not specified is to use all found Nvidia GPU cards.
#
#     -144             May be specified to request using EquiHash parameters
#                        144,5 (not required)
#     --algo 144_5     Synonym to -144
#
#     -temp-max t1 t2 ... Specifying one value (in Celsius) per each GPU.
#                             When specified temperature is reached, the
#                             solver suspends work until temperature drops
#                             to corresponding -temp-min.
#     -temp-max-all t  Defining the same upper temperature bound for all GPUs.
#
#     -temp-min t1 t2 ... Specifying one value (in Celsius) per each GPU.
#                             When GPU temperature drops from corresponding
#                             temp-max to temp-min work is resumed.
#                             When not specified -temp-min is defaulted
#                             to -temp-max minus 10.
#     -temp-min-all t  Defining the same lower temperature bound for all GPUs.
# 
#  Example:
#     ./funakoshiMiner --server main.pool.gold --port 3050
#                      --user your-wallet-address.worker-name

