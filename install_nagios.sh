#!/bin/bash

#===== Ubuntu 18.x =====
sudo apt-get update
sudo apt-get install -y autoconf gcc libc6 make wget unzip apache2 php libapache2-mod-php7.2 libgd-dev

#Downloading the Source
cd /tmp
wget -O nagioscore.tar.gz https://github.com/NagiosEnterprises/nagioscore/archive/nagios-4.4.5.tar.gz
tar xzf nagioscore.tar.gz

#Compile
cd /tmp/nagioscore-nagios-4.4.5/
sudo ./configure --with-httpd-conf=/etc/apache2/sites-enabled
sudo make all

#Create User And Group
sudo make install-groups-users
sudo usermod -a -G nagios www-data

#Install Binaries
sudo make install

#Install Service / Daemon
sudo make install-daemoninit

#Install Command Mode
sudo make install-commandmode

#Install SAMPLE Configuration Files
sudo make install-config

#Install Apache Config Files
sudo make install-webconf
sudo a2enmod rewrite
sudo a2enmod cgi

#Configure Firewall
sudo ufw allow Apache
sudo ufw reload

#Create nagiosadmin User Account
sudo htpasswd -c /usr/local/nagios/etc/htpasswd.users nagiosadmin

#Start Apache Web Server
sudo systemctl restart apache2.service

#Start Service / Daemon
sudo systemctl start nagios.service

#Installing The Nagios Plugins
sudo apt-get install -y autoconf gcc libc6 libmcrypt-dev make libssl-dev wget bc gawk dc build-essential snmp libnet-snmp-perl gettext

#Downloading The Source
cd /tmp
wget --no-check-certificate -O nagios-plugins.tar.gz https://github.com/nagios-plugins/nagios-plugins/archive/release-2.2.1.tar.gz
tar zxf nagios-plugins.tar.gz

#Compile + Install
cd /tmp/nagios-plugins-release-2.2.1/
sudo ./tools/setup
sudo ./configure
sudo make
sudo make install


