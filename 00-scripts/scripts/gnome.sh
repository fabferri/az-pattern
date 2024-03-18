#!/bin/bash

# print commands and arguments as they are executed
set -x

if [ "${UID}" -ne 0 ];
then
    echo "Script executed without root permissions"
    echo "You must be root to run this script." >&2
    exit 3
fi


# Setup Chrome
setup_chrome() {
   cd /tmp
   wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
   time sudo dpkg -i google-chrome-stable_current_amd64.deb
   time sudo apt-get -y install -f
   rm /tmp/google-chrome-stable_current_amd64.deb
}

# wait for the completion of the VM boot
sleep 10

# eliminate debconf warnings
echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
export DEBIAN_FRONTEND=noninteractive

# Update Ubuntu and install all necessary binaries
sudo apt-get -y update
sudo apt-get -y upgrade


time sudo apt-get -y install ubuntu-desktop-minimal 
time sudo apt-get -y install xrdp

sudo systemctl enable xrdp.service

# changed the allowed_users
sed -i "s/allowed_users=console/allowed_users=anybody/" /etc/X11/Xwrapper.config
/etc/init.d/xrdp restart


# Ubuntu uses a software component called Polkit, which is an application authorization framework that captures actions performed 
# by a user to check if the user is authorized to perform certain actions.
# When you connect to Ubuntu remotely using RDP / Windows Remote Desktop, you will see the above errors because the Polkit Policy file 
# cannot be accessed without superuser authentication.
# Configure the policy xrdp session
cat <<EOF > /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF

# Enable the Appearance option in the GNOME desktop 
su edge -c "touch /home/$admUser/.xsessionrc"
su edge -c "echo 'export GNOME_SHELL_SESSION_MODE=ubuntu' >> /home/$admUser/.xsessionrc"
su edge -c "echo 'export XDG_CURRENT_DESKTOP=ubuntu:GNOME' >> /home/$admUser/.xsessionrc"
su edge -c "echo 'export XDG_CONFIG_DIRS=/etc/xdg/xdg-ubuntu:/etc/xdg' >> /home/$admUser/.xsessionrc"


# Setup Chrome
setup_chrome

date

# different way to reboot the VM 
###### nohup shutdown -r +1 &
###### sudo /sbin/shutdown -r +1 
sudo systemctl reboot



