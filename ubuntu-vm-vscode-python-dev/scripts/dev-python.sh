#!/bin/bash

admUser="$1"

# print commands and arguments as they are executed
set -x

if [ "${UID}" -ne 0 ];
then
    echo "Script executed without root permissions"
    echo "You must be root to run this script." >&2
    exit 3
fi


setup_MicrosoftRepository() {
   # Download GPG Key to ensure packages authenticity
   curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
   sudo install -o root -g root -m 644 microsoft.gpg /etc/apt/trusted.gpg.d/
   sudo rm microsoft.gpg
}

# install VSCode
setup_VSCode() {
   # logger add log files to /var/log/syslog — from the command line and  scripts. the command "logger --tag" : mark every line with tag
   logger --tag devvm "Installing VSCode: $?"
   sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
   sudo apt-get -y update
   sudo DEBIAN_FRONTEND=noninteractive apt-get -y install code
   logger --tag devvm "VSCode Installed: $?"
   logger --tag devvm "Success"
}

# install dotnet LTS
setup_dotnet() {
   # scripted install dotnet SDK
   # The script defaults to installing the latest SDK long term support (LTS) version
   wget -P /tmp https://dot.net/v1/dotnet-install.sh  
   sudo chmod +x /tmp/dotnet-install.sh
   /tmp/dotnet-install.sh --install-dir /usr/share/dotnet/sdk
   touch /etc/profile.d/dotnet.sh
   echo 'export DOTNET_ROOT=/usr/share/dotnet/sdk' >> /etc/profile.d/dotnet.sh
   echo 'export PATH=$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools' >> /etc/profile.d/dotnet.sh
   rm -f /tmp/dotnet-install.sh
}

setup_edge() {
   # Setup Edge
   sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/edge stable main" > /etc/apt/sources.list.d/microsoft-edge.list'
   sudo apt-get -y update
   # Install Microsoft Edge Browser
   sudo apt-get -y install microsoft-edge-stable
}

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

# Setup Microsoft repository
setup_MicrosoftRepository

# Setup Visual Studio Code
setup_VSCode

# function to setup dotnet - uncomment the line below:
# setup_dotnet

# function to setup Microsoft edge - uncomment the line below:
# setup_edge

# Setup Chrome
setup_chrome

date

sudo apt-get -y install python3

sudo apt-get -y install python3-pip

# The virtual environment is deployed using the installed venv (virtual environment) package:
sudo apt-get -y install python3-venv

# install Visual Studio Code Extensions for Python:
su $admUser -c 'code --install-extension  ms-python.python'
logger -t devvm "Visual Studio Code python extension installed: $?"

# install Visual Studio Code Extension for Jupyter notebook
su $admUser -c 'code --install-extension  ms-toolsai.jupyter'
logger -t devvm "Visual Studio Code Jupyter notebook extension installed: $?"

# List of installed Visual Studio Code Extensions
su $admUser -c 'code --list-extensions'


# Enable in the GNOME desktop the Appearance option
su edge -c "touch /home/$admUser/.xsessionrc"
su edge -c "echo 'export GNOME_SHELL_SESSION_MODE=ubuntu' >> /home/$admUser/.xsessionrc"
su edge -c "echo 'export XDG_CURRENT_DESKTOP=ubuntu:GNOME' >> /home/$admUser/.xsessionrc"
su edge -c "echo 'export XDG_CONFIG_DIRS=/etc/xdg/xdg-ubuntu:/etc/xdg' >> /home/$admUser/.xsessionrc"

# different way to reboot the VM 
###### nohup shutdown -r +1 &
###### sudo /sbin/shutdown -r +1 
sudo systemctl reboot


