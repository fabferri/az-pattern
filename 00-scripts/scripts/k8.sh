#!/bin/bash
#
# script to install kubernetes in ubuntu
#
apt-get update
apt-get install -y bash-completion

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

# grab the OS version
OSVER=$(cat /etc/lsb-release | grep  DISTRIB_RELEASE | cut -d "=" -f2 )

if [ $OSVER = "20.04" ]
then
   # in ubutu 20.04
   mkdir /etc/apt/keyrings
fi

#
# GPG key used to verify the docker repo package 
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

#  install containerd runtime
sudo apt-get install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
# install containerd
sudo apt-get update
sudo apt-get install -y containerd.io

### configure containerd so that it starts using systemd as cgroup.
# containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
#sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

# the containerd version provided in Ubuntu repo is too old
# replace with recent version
sudo systemctl stop containerd

# to install the last version of containerd
# cleanup old files from previous attempt if existing
if [ -d "/var/temp/" ];
then
	[ -d /var/temp/bin ] && rm -rf /var/temp/bin
else
  mkdir /var/temp/
fi
wget https://github.com/containerd/containerd/releases/download/v1.6.19/containerd-1.6.19-linux-amd64.tar.gz -P /var/temp/
tar xzvf /var/temp/containerd-1.6.19-linux-amd64.tar.gz --directory /var/temp/
sudo mv /var/temp/bin/* /usr/bin/

# Configure containerd
sudo mkdir -p /etc/containerd
cat <<- TOML | sudo tee /etc/containerd/config.toml
version = 2
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".containerd]
      discard_unpacked_layers = true
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true
	TOML

#  restart and enable containerd service
sudo systemctl restart containerd
sudo systemctl enable containerd

# add apt repository for kubernetes
### NOTE: Xenial is the latest Kubernetes repository but when repository is available for Ubuntu 22.04 (Jammy Jellyfish) 
###       then you need replace xenial word with ‘jammy’ in ‘apt-add-repository’ command
sudo curl -fsSLo /etc/apt/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# install Kubernetes components Kubectl, kubeadm & kubelet
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl


## Manual step. To initialize Kubernetes cluster, on the master node run the command:
##    sudo kubeadm init 
##
##
##
