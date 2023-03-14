#!/bin/bash
#
# script to install kubernetes
#
apt update
apt install -y bash-completion

# disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

#load kernel modules
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# required sysctl to persist across system reboots
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# reload the above changes
sudo sysctl --system

#  install containerd runtime
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates

# in ubutu 20.04
mkdir /etc/apt/keyrings
#
# GPG key used to verify the docker repo package 
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# install containerd
sudo apt update
sudo apt install -y containerd.io

# configure containerd so that it starts using systemd as cgroup.
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

#  restart and enable containerd service
sudo systemctl restart containerd
sudo systemctl enable containerd

# add apt repository for kubernetes
### NOTE: Xenial is the latest Kubernetes repository but when repository is available for Ubuntu 22.04 (Jammy Jellyfish) 
###       then you need replace xenial word with ‘jammy’ in ‘apt-add-repository’ command
sudo curl -fsSLo /etc/apt/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# install Kubernetes components Kubectl, kubeadm & kubelet
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl


## Manual step. To initialize Kubernetes cluster, on the master node run the command:
##    sudo kubeadm init 
##
##
##
