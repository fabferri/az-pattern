#!/bin/bash

# eliminate debconf warnings
# echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
MOUNTIPADDRESS1="10.1.0.4"
MOUNTIPADDRESS2="10.1.0.4"
MOUNTIPADDRESS3="10.1.0.4"
VOLUMENAME1="netappVol1"
VOLUMENAME2="netappVol2"
VOLUMENAME3="netappVol3"
MOUNTPOINT1="/mnt/nfs1"
MOUNTPOINT2="/mnt/nfs2"
MOUNTPOINT3="/mnt/nfs3"


sudo apt-get -y update
sudo apt-get -y install nfs-common
sudo mkdir -p $MOUNTPOINT1
sudo mount -t nfs -o rw,hard,rsize=65536,wsize=65536,sec=sys,vers=4.1,tcp $MOUNTIPADDRESS1:/$VOLUMENAME1 $MOUNTPOINT1
sudo mkdir -p $MOUNTPOINT2
sudo mount -t nfs -o rw,hard,rsize=65536,wsize=65536,sec=sys,vers=4.1,tcp $MOUNTIPADDRESS2:/$VOLUMENAME2 $MOUNTPOINT2
sudo mkdir -p $MOUNTPOINT3
sudo mount -t nfs -o rw,hard,rsize=65536,wsize=65536,vers=3,tcp $MOUNTIPADDRESS3:/$VOLUMENAME3 $MOUNTPOINT3

