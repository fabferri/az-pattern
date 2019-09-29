#!/bin/bash
#
echo "$(tput setaf 1) iperf to internal s2-IPv6:$(tput setaf 7)"
#
iperf3 -6 -c cab:cab:cab:cab::5
