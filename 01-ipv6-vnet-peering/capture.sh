#!/bin/bash
#
echo "$(tput setaf 1) TCPDUMP$(tput setaf 7)"
tcpdump -i eth0 -nn -qq 'ip6 and (net abc:abc:abc:abc::/64 or net cab:cab:cab:cab::/64 or net ace:ace:ace:ace2::/64)'
