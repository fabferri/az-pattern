#!/bin/bash
#
### bash script has been tested out successful with CentOS 8.1
###
### terminal colours:
### \e[0m   --> reset all terminal attribute
### \e[92m  --> Light green
### \e[93m  --> Light yellow
### \e[96m  --> Light cyan colour
###
rst=$'\e[0m'
green=$'\e[92m'
yellow=$'\e[93m'
cyan=$'\e[96m'

offset=4
maxNumIP=254

## get IP address, subnetmask, network prefix
ip=$(ifconfig eth0 | awk '/netmask/{print $2}')
mask=$(ifconfig eth0 | awk '/netmask/{print $4}')
majorNet=$(ifconfig eth0 | awk '/netmask/{print $2}' | cut -d'.' -f 1-3)
netw="$majorNet."



portRangeStart=8080
numIP="$(($maxNumIP-$offset))"
portRangeEnd=$((portRangeStart+maxNumIP))
portRange="$portRangeStart-$portRangeEnd"


#
### OS update, install httpd daemon, enable and start httpd daemon
dnf -y update

### assign the output of command to the variable $var1
var1=$(dnf list installed httpd)
var2="httpd"

### check if httpd daemon is installed 
if [ "$var1" = "$var2" ]; then
    printf '%s\n' "httpd daemon already installed"
else
    printf "$(date +"%T")-"
    printf '%s\n' "${yellow}installing httpd daemon ${rst}"
    dnf -y install httpd
fi

printf '%s\n' "${cyan}enable and start httpd ${rst}"
systemctl enable httpd
systemctl start httpd
sleep 5
### check if httpd is running
ps -C httpd >/dev/null && printf '%s\n' "httpd is running" || printf '%s\n' "httpd NOT running!"
pidof httpd >/dev/null && printf '%s\n' "httpd is running" || printf '%s\n' "httpd NOT running!"

### install package to change SElinux
dnf install -y setroubleshoot-server
###
### SElinux: check enabled ports on httpd
str11="$(semanage port -l | grep -w http_port_t)"
if [[ $str11 == *"http_port_t"* ]]; then
  printf "\n"
  printf '%s\n' "${yellow}check SELinux on httpd: OK ${rst}"
  printf "$str11\n"
  if [[ $str11 != *"$portRange"* ]]; then
    semanage port -a -t http_port_t -p tcp "${portRange}"
    printf '%s\n' "${green}SELinux- list of port enabled on httpd: ${rst}"
    listPorts=$(semanage port -l | grep "^http_port_t")
    printf '%s\n' "${green}$listPorts ${rst}"
    printf "\n"
  fi
fi

###########################################
###########################################
### Setup multiple IPs in the same network adapter
for (( i = 0; i < $((numIP - 1)) ; i++ )); do
    nameFolder=/etc/sysconfig/network-scripts
    k=$((i + 5))
    fileName="ifcfg-eth0:$k"
    destFile="$nameFolder/$fileName"
    if [ -f "$destFile" ]; then
       printf "$(date +"%T")-"
       printf '%s\n' "$destFile already exists!"
    else 
      printf "$(date +"%T")-"
      printf '%s\n' "file: $destFile does not exists."
      printf '%s\n' "${cyan}create the file: $destFile ${rst}"
      touch $destFile
      text="DEVICE=eth0:$k\n"
      text+="NAME=eth0:$k\n"
      text+="BOOTPROTO=static\n"
      text+="ONBOOT=yes\n"
      text+="TYPE=Ethernet\n"
      addr="${netw}${k}"
      text+="IPADDR=$addr\n"
      text+="NETMASK=$mask\n"
      text+="NM_CONTROLLED=yes\n"
      echo -e "$text" >  "$destFile"
    fi
done

### reload the network settings
printf '%s\n' "restart NetworkManager"
systemctl restart NetworkManager
sleep 3
nmcli networking off; nmcli networking on
# nmcli device reapply eth0
val=$(ip addr show eth0)
###########################################

printf '%s\n' "${cyan}List of IPs:"
ip addr show eth0 | grep -o "inet [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*"
printf '%s\n' "${rst}"
sleep 8
### add multiple Listen
### to the httpd config file /etc/httpd/conf/httpd.conf
file1="/etc/httpd/conf/httpd.conf"
declare -a arrListener
if [ -f $file1 ]
then
    printf '%s\n' "${yellow}httpd config file $file1 found! ${rst}"
else
    printf '%s\n' "${yellow}httpd config file not found! ${rst}"
fi

for (( i = 0; i < $numIP ; i++ )); do
  k=$((i + 4))
  if [ $i -eq 0 ]
  then
      port=80
      addr="${netw}${k}"
      str1='Listen 80'
      str2="Listen $addr:$port"
  else
      port=$((k + 8080))
      addr="${netw}${k}"
      str1=$str2
      str2="Listen $addr:$port"
  fi
  sed -i "/$str1/a $str2" "$file1"
  arrListener[$i]="${str2}"
done

### remove the default line 'Listen 80'
printf '%s\n' "${green}removing the line Listener 80 ${rst}"
str1='Listen 80'
sed -i "/$str1/d" "$file1"
###
### print the 
printf '%s\n' "${green}list of httpd Listener: ${rst}"
for i in "${arrListener[@]}"
do
  printf '%s\n' "${green}   $i ${rst}"
done
sleep 5
###########################################
### Create the directory structure
for (( i = 0; i < $numIP ; i++ )); do
  k=$((i + 4))
  dirfolder="/var/www/html/www$k.com"
  idxfile="$dirfolder/index.html"

  if [ -f $idxfile ]
  then
    ### $yellow light green
    printf '%s\n' "${yellow}file $idxfile already exists ${rst}"
  else
    printf '%s\n' "${yellow}create file $idxfile ${rst}"
    mkdir -p $dirfolder
    touch $idxfile
    text="<html>\n"
    text+="<head>\n"
    text+="<title>www$k.com</title>\n"
    text+="</head>\n"
    text+="<body>\n"
    text+="<h1>the virtual host www$k.com is working!</h1>\n"
    text+="</body>\n"
    text+="</html>\n"
    echo -e "$text" > "$idxfile"
    chown -R apache:apache $dirfolder
  fi
done
sleep 5
###########################################
### Virtual Host Directives in the folder /etc/httpd/conf.d/
for (( i = 0; i < $numIP ; i++ )); do
    k=$((i + 4))
    if [ $i -eq 0 ]
    then
      port=80
    else
      port=$((k + 8080))
    fi
    addr="${netw}${k}"
    nameFolder="/etc/httpd/conf.d/"
    fileName="www$k.com.conf"
    destFile="$nameFolder/$fileName"

    if [ -f $destFile ]
    then
       printf '%s\n' "${cyan}config file $destFile already exists ${rst}"
    else
      printf '%s\n' "${cyan}create config file: $destFile ${rst}"
      touch $destFile
      printf '%s\n' "<VirtualHost $addr:$port>" >> $destFile
      printf '%s\n' "ServerName www$k.com" >> $destFile
      printf '%s\n' "ServerAlias www$k.com" >> $destFile
      printf '%s\n' "DocumentRoot /var/www/html/www$k.com" >> $destFile
      printf '%s\n' "ErrorLog /var/log/httpd/www$k.com-error.log" >> $destFile
      printf '%s\n' "CustomLog /var/log/httpd/www$k.com-access.log combined" >> $destFile
      printf '%s\n' "</VirtualHost>" >> $destFile
   fi
done
sleep 5

printf '%s' "${cyan}checking httpd config: ${rst}"
apachectl configtest

### restart httpd
systemctl restart httpd
pidof httpd >/dev/null && printf '%s\n' "httpd is running" || printf '%s\n' "httpd NOT running!"
exit 1
