#!/usr/bin/env bash
#
#
# Capima installer script for Ubuntu servers
#
# USE AT YOUR OWN RISKS!
#

OSNAME=`lsb_release -s -i`
OSVERSION=`lsb_release -s -r`
OSCODENAME=`lsb_release -s -c`
SUPPORTEDVERSION="16.04 18.04"
PHPCLIVERSION="php73rc"
INSTALLPACKAGE="nginx-rc apache2-rc curl git wget mariadb-server expect nano openssl redis-server python-setuptools python-pip perl zip unzip net-tools bc fail2ban augeas-tools libaugeas0 augeas-lenses firewalld build-essential acl memcached beanstalkd passwd unattended-upgrades postfix nodejs make "

function ReplaceWholeLine {
    sed -i "s/$1.*/$2/" $3
}

function ReplaceTrueWholeLine {
    sed -i "s/.*$1.*/$2/" $3
}

function checkServiceInstalled {
    if rpm -qa | grep -q $1; then
        return 1
    else
        return 0
    fi
}

function RandomString {
    head /dev/urandom | tr -dc _A-Za-z0-9 | head -c55
}

function FixAutoUpdate() {
    AUTOUPDATEFILE50="/etc/apt/apt.conf.d/50unattended-upgrades"
    AUTOUPDATEFILE20="/etc/apt/apt.conf.d/20auto-upgrades"

    sed -i 's/Unattended-Upgrade::Allowed-Origins {/Unattended-Upgrade::Allowed-Origins {\n        "RunCloud:${distro_codename}";/g' $AUTOUPDATEFILE50
    ReplaceTrueWholeLine "\"\${distro_id}:\${distro_codename}-security\";" "        \"\${distro_id}:\${distro_codename}-security\";" $AUTOUPDATEFILE50
    ReplaceTrueWholeLine "\/\/Unattended-Upgrade::AutoFixInterruptedDpkg" "Unattended-Upgrade::AutoFixInterruptedDpkg \"true\";" $AUTOUPDATEFILE50
    ReplaceTrueWholeLine "\/\/Unattended-Upgrade::Remove-Unused-Dependencies" "Unattended-Upgrade::Remove-Unused-Dependencies \"true\";" $AUTOUPDATEFILE50

    echo -ne "\n\n
    Dpkg::Options {
       \"--force-confdef\";
       \"--force-confold\";
    }" >> $AUTOUPDATEFILE50

    echo "APT::Periodic::Update-Package-Lists \"1\";" > $AUTOUPDATEFILE20
    echo "APT::Periodic::Unattended-Upgrade \"1\";" >> $AUTOUPDATEFILE20
}

function BootstrapServer {
    apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade -y
}

function BootstrapInstaller {
    rm -f /etc/apt/apt.conf.d/50unattended-upgrades.ucf-dist

    apt-get install software-properties-common apt-transport-https -y

    # Install Key
    # RunCloud
    wget -qO - https://release.runcloud.io/runcloud.key | apt-key add -
    # MariaDB
    apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8

    # Install RunCloud Source List
    echo "deb [arch=amd64] https://release.runcloud.io/ $OSCODENAME main" > /etc/apt/sources.list.d/runcloud.list

    # LTS version nodejs
    curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -

    if [[ "$OSCODENAME" == 'xenial' ]]; then
        add-apt-repository 'deb [arch=amd64] http://nyc2.mirrors.digitalocean.com/mariadb/repo/10.2/ubuntu xenial main'
        add-apt-repository 'deb [arch=amd64] http://sfo1.mirrors.digitalocean.com/mariadb/repo/10.2/ubuntu xenial main'

        INSTALLPACKAGE+="php55rc php55rc-essentials php56rc php56rc-essentials php70rc php70rc-essentials php71rc php71rc-essentials php72rc php72rc-essentials php73rc php73rc-essentials"
    elif [[ "$OSCODENAME" == 'bionic' ]]; then
        add-apt-repository 'deb [arch=amd64] http://nyc2.mirrors.digitalocean.com/mariadb/repo/10.2/ubuntu bionic main'
        add-apt-repository 'deb [arch=amd64] http://sfo1.mirrors.digitalocean.com/mariadb/repo/10.2/ubuntu bionic main'

        INSTALLPACKAGE+="php70rc php70rc-essentials php71rc php71rc-essentials php72rc php72rc-essentials php73rc php73rc-essentials"
    fi

    # APT PINNING
    echo "Package: *
Pin: release o=MariaDB
Pin-Priority: 900" > /etc/apt/preferences

}

function EnableSwap {
    totalRAM=`grep MemTotal /proc/meminfo | awk '{print $2}'`
    if [[ $totalRAM -lt 4000000 ]]; then # kalau RAM less than 4GB, enable swap
        swapEnabled=`swapon --show | wc -l`
        if [[ $swapEnabled -eq 0 ]]; then # swap belum enable
            # create 2GB swap space
            fallocate -l 2G /swapfile
            chmod 600 /swapfile
            mkswap /swapfile
            swapon /swapfile

            # backup fstab
            cp /etc/fstab /etc/fstab.bak

            # register the swap to fstab
            echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
        fi
    fi
}

function InstallPackage {
    apt-get update
    apt-get remove mysql-common --purge -y

    apt-get install $INSTALLPACKAGE -y
}

function BootstrapSupervisor {
    export LC_ALL=C
    pip install supervisor
    echo_supervisord_conf > /etc/supervisord.conf
    echo -ne "\n\n\n[include]\nfiles=/etc/supervisor.d/*.conf\n\n" >> /etc/supervisord.conf
    mkdir -p /etc/supervisor.d

    echo "[Unit]
Description=supervisord - Supervisor process control system for UNIX
Documentation=http://supervisord.org
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/supervisord -c /etc/supervisord.conf
ExecReload=/usr/local/bin/supervisorctl reload
ExecStop=/usr/local/bin/supervisorctl shutdown
User=root

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/supervisord.service

    systemctl daemon-reload
}

function BootstrapFail2Ban {
    echo "# Capima Server API configuration file
#
# Author: Toan Nguyen
#

[Definition]
failregex = Authentication error from <HOST>" > /etc/fail2ban/filter.d/capima-agent.conf

    echo "[DEFAULT]
ignoreip = 127.0.0.1/8
bantime = 36000
findtime = 600
maxretry = 5


[sshd]
enabled = true
logpath = %(sshd_log)s
port = 22
banaction = iptables

[sshd-ddos]
enabled = true
logpath = %(sshd_log)s
banaction = iptables-multiport

[capima-agent]
enabled = true
logpath = /var/log/capima.log
port = 34210
banaction = iptables
maxretry = 2" > /etc/fail2ban/jail.local
}

function BootstrapMariaDB {
    mkdir -p /tmp/lens
    wget $CAPIMAURL/files/lenses/augeas-mysql.aug -O /tmp/lens/mysql.aug


    ROOTPASS=$(RandomString)

    # Start mariadb untuk initialize
    systemctl start mysql

    SECURE_MYSQL=$(expect -c "
set timeout 5
spawn mysql_secure_installation

expect \"Enter current password for root (enter for none):\"
send \"\r\"

expect \"Change the root password?\"
send \"y\r\"

expect \"New password:\"
send \"$ROOTPASS\r\"

expect \"Re-enter new password:\"
send \"$ROOTPASS\r\"

expect \"Remove anonymous users?\"
send \"y\r\"

expect \"Disallow root login remotely?\"
send \"y\r\"

expect \"Remove test database and access to it?\"
send \"y\r\"

expect \"Reload privilege tables now?\"
send \"y\r\"

expect eof
")
    echo "$SECURE_MYSQL"


#     /usr/bin/augtool -I /tmp/lens/ <<EOF
# set /files/etc/mysql/my.cnf/target[ . = "client" ]/user root
# set /files/etc/mysql/my.cnf/target[ . = "client" ]/password $ROOTPASS
# save
# EOF

/usr/bin/augtool -I /tmp/lens/ <<EOF
set /files/etc/mysql/my.cnf/target[ . = "client" ]/user root
set /files/etc/mysql/my.cnf/target[ . = "client" ]/password $ROOTPASS
set /files/etc/mysql/my.cnf/target[ . = "mysqld" ]/bind-address 0.0.0.0
set /files/etc/mysql/conf.d/mariadb.cnf/target[ . = "mysqld" ]/innodb_file_per_table 1
set /files/etc/mysql/conf.d/mariadb.cnf/target[ . = "mysqld" ]/max_connections 15554
set /files/etc/mysql/conf.d/mariadb.cnf/target[ . = "mysqld" ]/query_cache_size 80M
set /files/etc/mysql/conf.d/mariadb.cnf/target[ . = "mysqld" ]/query_cache_type 1
set /files/etc/mysql/conf.d/mariadb.cnf/target[ . = "mysqld" ]/query_cache_limit 2M
set /files/etc/mysql/conf.d/mariadb.cnf/target[ . = "mysqld" ]/query_cache_min_res_unit 2k
set /files/etc/mysql/conf.d/mariadb.cnf/target[ . = "mysqld" ]/thread_cache_size 60
save
EOF

echo "[client]
user=root
password=$ROOTPASS
" > /etc/mysql/conf.d/root.cnf

    chmod 600 /etc/mysql/conf.d/root.cnf
}

function BootstrapWebApplication {
    USER="capima"
    CAPIMAPASSWORD=$(RandomString)
    HOMEDIR="/srv/users/$USER/"
    groupadd users-cpm
    mkdir -p "/srv/users"
    adduser --disabled-password --gecos "" --home $HOMEDIR $USER
    usermod -a -G users-cpm $USER

    echo "$USER:$CAPIMAPASSWORD" | chpasswd
    chmod 755 /srv/users
    mkdir -p $HOMEDIR/logs/{nginx,apache2,fpm}

    # FACL
    setfacl -m g:users-cpm:x /srv/users
    setfacl -Rm g:users-cpm:- /srv/users/$USER
    setfacl -Rm g:users-cpm:- /etc/mysql
    setfacl -Rm g:users-cpm:- /var/log
    setfacl -Rm g:$USER:rx /srv/users/$USER/logs


    mkdir -p /opt/Capima/{.ssh,letsencrypt}


    echo "-----BEGIN DH PARAMETERS-----
MIICCAKCAgEAzZmGWVJjBWNtfh1Q4MrxFJ5uwTM6xkllSewPOdMq5BYmXOFAhYMr
vhbig5AJHDexbl/VFp64S6JaokQRbTtiibBfHV92LCK9hVRJ2eB7Wlg6t5+YYjKc
QiNxQ/uvSG3eqmAAr39V3oUWxeyCj/b1WdUVkDuKdJyHevDgfaoyFl7JHymxwvrn
HR9/x7lH5o2Uhl60uYaZxlhzbbrqMU/ygx9JCj6trL5C5pv9hpH+2uJdvkp/2NJj
BJCwiHmLMlfqXA3H8/T7L0vn/QLk1JUmqQeGdvZFqEmCe//LAT8llGofawtOUUwT
v65K1Ovagt7R9iu+nOFIh6XPsLVLemq2HFy+amk+Ti4UZ+EJxvO+s84LxSvAqjsk
clEE2v+AlIbe8Hjo6YzubXtqSrFLD049kxocPdQXqbDbvlI6br1UjYgWl08upKSZ
fIwCFFsqwE4y7zRg1VY7MKc0z6MCBU7om/gI4xlPSSBxAP1fN9hv6MbSV/LEvWxs
pFyShqTqefToDKiegPpqBs8LAsOtuH78eSm18SgKYpVPL1ph0VhhbphbsmKxmqaU
+EP6bSOc2tTwCMPWySQslHN4TdbsiQJE/gJuVeaCLM1+u4sd0rU9NQblThPuOILp
v03VfaTd1dUF1HmcqJSl/DYeeBVYjT8GtAKWI5JrvCKDIPvOB98xMysCAQI=
-----END DH PARAMETERS-----" > /etc/nginx-rc/dhparam.pem
}

function BootstrapFirewall {
    # Stop iptables
    systemctl stop iptables
    systemctl stop ip6tables
    systemctl mask iptables
    systemctl mask ip6tables


    # remove ufw
    apt-get remove ufw -y
    # Start firewalld
    systemctl enable firewalld
    systemctl start firewalld

    echo "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<zone>
  <short>Capima</short>
  <description>Default zone to use with Capima Server</description>
  <service name=\"rcsa\"/>
  <service name=\"dhcpv6-client\"/>
  <port protocol=\"tcp\" port=\"22\"/>
  <port protocol=\"tcp\" port=\"80\"/>
  <port protocol=\"tcp\" port=\"443\"/>
</zone>" > /etc/firewalld/zones/capima.xml

    sleep 3

    firewall-cmd --reload # reload to get rcsa
    firewall-cmd --set-default-zone=capima
    firewall-cmd --reload # reload to enable new config
}

function InstallComposer {
    ln -s /RunCloud/Packages/$PHPCLIVERSION/bin/php /usr/bin/php

    source /etc/profile.d/capimapath.sh
    # php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    wget -4 https://getcomposer.org/installer -O composer-setup.php
    php composer-setup.php
    php -r "unlink('composer-setup.php');"
    mv composer.phar /usr/sbin/composer

}

function RegisterPathAndTweak {
    echo "#!/bin/sh
export PATH=/RunCloud/Packages/apache2-rc/bin:\$PATH" > /etc/profile.d/capimapath.sh

    echo fs.inotify.max_user_watches=524288 | tee -a /etc/sysctl.conf && sysctl -p
    echo net.core.somaxconn = 65536 | tee -a /etc/sysctl.conf && sysctl -p
    echo net.ipv4.tcp_max_tw_buckets = 1440000 | tee -a /etc/sysctl.conf && sysctl -p
    echo vm.swappiness=10 | tee -a /etc/sysctl.conf && sysctl -p
    echo vm.vfs_cache_pressure=50 | tee -a /etc/sysctl.conf && sysctl -p
    echo vm.overcommit_memory=1 | tee -a /etc/sysctl.conf && sysctl -p


    /usr/bin/augtool <<EOF
set /files/etc/ssh/sshd_config/UseDNS no
set /files/etc/ssh/sshd_config/PasswordAuthentication yes
set /files/etc/ssh/sshd_config/PermitRootLogin yes
save
EOF
    systemctl restart sshd

    wget $CAPIMAURL/files/scripts/capima.sh -O /usr/sbin/capima
    chmod +x /usr/sbin/capima
}

function BootstrapSystemdService {

    systemctl disable supervisord
    systemctl stop supervisord

    systemctl disable redis-server
    systemctl stop redis-server

    systemctl disable memcached
    systemctl stop memcached

    systemctl disable beanstalkd
    systemctl stop beanstalkd



    # Fix fail2ban
    touch /var/log/capima.log

    systemctl enable fail2ban
    systemctl start fail2ban
    systemctl restart fail2ban

    systemctl enable mysql
    systemctl restart mysql

    systemctl enable $PHPCLIVERSION-fpm.service
    systemctl restart $PHPCLIVERSION-fpm.service

    systemctl enable nginx-rc.service
    systemctl restart nginx-rc.service

    systemctl enable redis-server.service
    systemctl restart redis-server.service

}

CAPIMAURL="https://capima.nntoan.com"

locale-gen en_US en_US.UTF-8

export LANGUAGE=en_US.utf8
export LC_ALL=en_US.utf8
export DEBIAN_FRONTEND=noninteractive

# Checker
if [[ $EUID -ne 0 ]]; then
    message="Capima installer must be run as root!"
    echo $message 1>&2
    exit 1
fi

if [[ "$OSNAME" != "Ubuntu" ]]; then
    message="This installer only support $OSNAME"
    echo $message
    exit 1
fi

if [[ $(uname -m) != "x86_64" ]]; then
    message="This installer only support x86_64 architecture"
    echo $message
    exit 1
fi

grep -q $OSVERSION <<< $SUPPORTEDVERSION
if [[ $? -ne 0 ]]; then
    message="This installer does not support $OSNAME $OSVERSION"
    echo $message
    exit 1
fi


# Bootstrap the server
BootstrapServer

# Bootstrap the installer
BootstrapInstaller

# Enabling Swap if Not Enabled
sleep 2
EnableSwap

# Install The Packages
sleep 2
InstallPackage

# Supervisor
sleep 2
BootstrapSupervisor

# Fail2Ban
sleep 2
BootstrapFail2Ban

# MariaDB
sleep 2
BootstrapMariaDB

# Web Application
sleep 2
BootstrapWebApplication

# Auto Update
sleep 2
FixAutoUpdate

# Firewall
sleep 2
BootstrapFirewall

# Composer
sleep 2
InstallComposer

# Tweak
sleep 2
RegisterPathAndTweak

# Systemd Service
sleep 2
BootstrapSystemdService


## CLEANUP
# This will only run coming from direct installation
if [ -f /tmp/installer.sh ]; then
    rm /tmp/installer.sh
fi
if [ -f /tmp/installation.log ]; then
    rm /tmp/installation.log
fi

############################# MOTD ##################################

echo "

 .d8888b.                    d8b                        
d88P  Y88b                   Y8P                        
888    888                                              
888         8888b.  88888b.  888 88888b.d88b.   8888b.  
888            \"88b 888 \"88b 888 888 \"888 \"88b     \"88b 
888    888 .d888888 888  888 888 888  888  888 .d888888 
Y88b  d88P 888  888 888 d88P 888 888  888  888 888  888 
 \"Y8888P\"  \"Y888888 88888P\"  888 888  888  888 \"Y888888 
                    888                                 
                    888                                 
                    888                                 


- Do not use \"root\" user to create/modify any web app files
- Do not edit any config commented with \"Do not edit\"

Made with ♥ by Toan Nguyen

" > /etc/motd


###################################### INSTALL SUMMARY #####################################
clear
echo -ne "\n
#################################################
# Finished installation. Do not lose any of the
# data below.
##################################################
\n
\n
\nMySQL ROOT PASSWORD: $ROOTPASS
User: $USER
Password: $CAPIMAPASSWORD
\n
\n
You can now manage your server using $CAPIMAURL
"