#!/usr/bin/env bash

function RandomString {
  head /dev/urandom | tr -dc '_$!*&%#A-Za-z0-9' | head -c14
}

function AuthorizedKeys {
  curl -4 --silent --location "$CAPIMAURL/files/pubkeys/vmi.pub"
}

function BootstrapSSHService() {
  sed -i 's/^#HostKey \/etc\/ssh\/ssh_host_rsa_key/HostKey \/etc\/ssh\/ssh_host_rsa_key/'  /etc/ssh/sshd_config;
  sed -i 's/^#HostKey \/etc\/ssh\/ssh_host_ecdsa_key//'  /etc/ssh/sshd_config;
  sed -i 's/^#HostKey \/etc\/ssh\/ssh_host_ed25519_key//'  /etc/ssh/sshd_config;
  sed -i 's/^#Protocol 2/Protocol 2/'  /etc/ssh/sshd_config;
  sed -i 's/^#Protocol 2/Protocol 2/'  /etc/ssh/sshd_config;
  sed -i 's/^PermitRootLogin yes/PermitRootLogin forced-commands-only/'  /etc/ssh/sshd_config;
  sed -i 's/^#AuthorizedKeysFile     .ssh\/authorized_keys .ssh\/authorized_keys2/AuthorizedKeysFile .ssh\/authorized_keys/'  /etc/ssh/sshd_config;
  sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/'  /etc/ssh/sshd_config;
  echo "\n# Legacy guideliness" >> /etc/ssh/sshd_config;
  echo "KexAlgorithms diffie-hellman-group-exchange-sha256" >> /etc/ssh/sshd_config;
  echo "Ciphers aes256-ctr,aes192-ctr,aes128-ctr" >> /etc/ssh/sshd_config;
  echo "MACs hmac-sha2-256,hmac-sha2-512" >> /etc/ssh/sshd_config;
  echo "KeyRegenerationInterval 1800" >> /etc/ssh/sshd_config;
  echo "AuthenticationMethods publickey" >> /etc/ssh/sshd_config;
}

function BootstrapSudoUser {
  echo -ne "Creating contabo user"
  useradd -u 1000 contabo -m -s /bin/bash
  usermod -a -G sudo contabo
  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""
}

function BootstrapContaboKeys {
  homedir=$(getent passwd root | cut -d ':' -f6)
  root_u="root"
  contabo_user="contabo"
  contabo_key=$(AuthorizedKeys)
  ctb_homedir=$(getent passwd $contabo_user | cut -d ':' -f6)
  if [[ -f "$ctb_homedir/.ssh/authorized_keys" ]]; then
    echo -ne "Adding SSH keys for Contabo user"
    mkdir -p "$ctb_homedir/.ssh"
    echo $contabo_key > "$ctb_homedir/.ssh/authorized_keys"
    chown -Rf $contabo_user:$contabo_user "$ctb_homedir/.ssh"
    echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
    echo ""
  fi

  if [[ -f "$homedir/.ssh/authorized_keys" ]]; then
    echo -ne "Added SSH keys for root user"
    mkdir -p "$homedir/.ssh"
    echo $contabo_key > "$homedir/.ssh/authorized_keys"
    echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
    echo ""
  fi
}

function CheckingRemoteAccessible {
    echo -ne "\n\n\nChecking if $CAPIMAURL is accessible...\n"

    # send command to check wait 2 seconds inside jobs before trying
    timeout 15 bash -c "curl -4 -I --silent $CAPIMAURL | grep 'HTTP/2 200' &>/dev/null"
    status="$?"
    if [[ "$status" -ne 0 ]]; then
        clear
echo -ne "\n
##################################################
# Unable to connect to Capima server from this   #
# Please take a coffee or take a nap and rerun   #
# the installation script again!                 #
##################################################
\n\n\n
"
        exit 1
    fi
}

CAPIMAURL="https://capima.nntoan.com"

locale-gen en_US en_US.UTF-8

export LANGUAGE=en_US.utf8
export LC_ALL=en_US.utf8
export DEBIAN_FRONTEND=noninteractive

# Checker
if [[ $EUID -ne 0 ]]; then
    message="Must be run as root!"
    echo $message 1>&2
    exit 1
fi

# Checking if server is up
CheckingRemoteAccessible

# Bootstrap users
BootstrapSudoUser

# Bootstrap SSH keys
sleep 2
BootstrapContaboKeys

# Bootstrap SSHD service
sleep 2
BootstrapSSHService

