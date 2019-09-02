#!/bin/bash
#
# script to run on s1 to check the reachability of VMs
#
STR=$'\n'
$echo "$(tput setaf 1) IPv6\n"
ip -6 addr show

read -n 1 -s -r -p "$(tput setaf 2)Press any key to continue$(tput setaf 7)"
echo ""
echo "----------------------------"
echo "$(tput setaf 3)ping to s2-IPv6: $(tput setaf 7)"
ping6 cab:cab:cab:cab::5 -c 3

read -n 1 -s -r -p "$(tput setaf 2)Press any key to continue$(tput setaf 7)"
echo ""
echo "----------------------------"
echo "$(tput setaf 3)ping to h2-IPv6: $(tput setaf 7)"
ping6 ace:ace:ace:ace2::50  -c 3

read -n 1 -s -r -p "$(tput setaf 2)Press any key to continue$(tput setaf 7)"
echo ""
echo "----------------------------"
echo "$(tput setaf 3)ping to h12-IPv6: $(tput setaf 7)"
ping6 ace:ace:ace:ace1::4  -c 3

read -n 1 -s -r -p "$(tput setaf 2)Press any key to continue$(tput setaf 7)"
echo ""
echo "----------------------------"
echo "$(tput setaf 3)ping to h11-IPv6: $(tput setaf 7)"
ping6 ace:ace:ace:ace1::5  -c 3


#reset color to white
echo "$(tput setaf 7)"
