#!/usr/bin/env bash

function RandomString {
  head /dev/urandom | tr -dc '_$!*&%#A-Za-z0-9' | head -c14
}

function GetContaboKeyS3Uri {
  if [[ -z "$INSTANCE_ID" ]]; then
    echo "s3://$CONTABO_BOOTBUCKET/keys/vmi.pub"
  else
    echo "s3://$CONTABO_BOOTBUCKET/keys/vmi${INSTANCE_ID}.pub"
  fi
}

function BootstrapSSHService() {
  homedir=$(getent passwd root | cut -d ':' -f6)

  if [[ ! -f $homedir/.sshd_tweaks ]]; then
    sed -i 's/^#HostKey \/etc\/ssh\/ssh_host_rsa_key/HostKey \/etc\/ssh\/ssh_host_rsa_key/'  /etc/ssh/sshd_config;
    sed -i 's/^#HostKey \/etc\/ssh\/ssh_host_ecdsa_key//'  /etc/ssh/sshd_config;
    sed -i 's/^#HostKey \/etc\/ssh\/ssh_host_ed25519_key//'  /etc/ssh/sshd_config;
    sed -i 's/^#Protocol 2/Protocol 2/'  /etc/ssh/sshd_config;
    sed -i 's/^#Protocol 2/Protocol 2/'  /etc/ssh/sshd_config;
    sed -i 's/^PermitRootLogin yes/PermitRootLogin forced-commands-only/'  /etc/ssh/sshd_config;
    sed -i 's/^#AuthorizedKeysFile     .ssh\/authorized_keys .ssh\/authorized_keys2/AuthorizedKeysFile .ssh\/authorized_keys/'  /etc/ssh/sshd_config;
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/'  /etc/ssh/sshd_config;
    echo "" >> /etc/ssh/sshd_config;
    echo "# Legacy guideliness" >> /etc/ssh/sshd_config;
    echo "KexAlgorithms diffie-hellman-group-exchange-sha256" >> /etc/ssh/sshd_config;
    echo "Ciphers aes256-ctr,aes192-ctr,aes128-ctr" >> /etc/ssh/sshd_config;
    echo "MACs hmac-sha2-256,hmac-sha2-512" >> /etc/ssh/sshd_config;
    echo "KeyRegenerationInterval 1800" >> /etc/ssh/sshd_config;
    echo "AuthenticationMethods publickey" >> /etc/ssh/sshd_config;
    touch $homedir/.sshd_tweaks
    echo $(date +%s) > $homedir/.sshd_tweaks
    systemctl restart sshd.service
  fi
}

function BootstrapSudoUser {
  user_exists=$(id -u contabo > /dev/null 2>&1; echo $?)
  if [[ "$user_exists" == 1 ]]; then
    echo -ne "Creating contabo user"
    useradd -u 1000 contabo -m -s /bin/bash
    usermod -a -G sudo contabo
    echo "contabo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/contabo
    runuser -l contabo -c "touch /home/contabo/.sudo_as_admin_successful"
    echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
    echo ""
  else
    echo -ne "User contabo exists. Skipping.."
    echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
    echo ""
  fi
}

function BootstrapContaboKeys {
  homedir=$(getent passwd root | cut -d ':' -f6)
  root_u="root"
  contabo_user="contabo"
  pubkey=$(GetContaboKeyS3Uri $INSTANCE_ID)
  ctb_homedir=$(getent passwd $contabo_user | cut -d ':' -f6)

  if [[ ! -f "$ctb_homedir/.ssh/authorized_keys" ]]; then
    echo -ne "Deploying internal SSH public keys [contabo]";
    runuser -l contabo -c "mkdir -p ${ctb_homedir}/.ssh;";
    runuser -l contabo -c "aws s3 cp ${pubkey} ${ctb_homedir}/.ssh --quiet --only-show-errors --no-progress";
    runuser -l contabo -c "cat ${ctb_homedir}/.ssh/vmi${INSTANCE_ID}.pub >> ${ctb_homedir}/.ssh/authorized_keys";
    rm -rf ${ctb_homedir}/.ssh/vmi${INSTANCE_ID}.pub;
    echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
    echo ""
  else
    echo -ne "SSH pub key (contabo) exists. Skip deploying.."
    echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
    echo ""
  fi

  if [[ ! -f "$homedir/.ssh/authorized_keys" ]]; then
    echo -ne "Deploying internal SSH public keys [root]"
    mkdir -p "$homedir/.ssh"
    aws s3 cp "$pubkey" "$homedir/.ssh" --quiet --only-show-errors --no-progress
    cat "${homedir}/.ssh/vmi${INSTANCE_ID}.pub" >> $homedir/.ssh/authorized_keys
    rm -rf "${homedir}/.ssh/vmi${INSTANCE_ID}.pub";
    echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
    echo ""
  else
    echo -ne "SSH pub key (root) exists. Skip deploying.."
    echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
    echo ""
  fi
}

function BootstrapAwsCli {
  # Install required tools
  echo -ne "Updating apt, installing software"
  apt-get -qq update && apt-get -qq install apt-transport-https ca-certificates curl gnupg ruby jq awscli -y
  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""

  # Set up variables
  if [[ ! -f "/etc/profile.d/awscreds.sh" ]]; then
    echo -ne "Deploying AWS credentials"
    touch /etc/profile.d/awscreds.sh
    echo "export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}" >> /etc/profile.d/awscreds.sh
    echo "export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}" >> /etc/profile.d/awscreds.sh
    echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
    echo ""
  else
    echo -ne "AWS credentials configured. Skip deploying.."
    echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
    echo ""
  fi

  source /etc/profile
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

# Set variables
INSTANCE_ID="$1"
AWS_ACCESS_KEY_ID="$2"
AWS_SECRET_ACCESS_KEY="$3"
CAPIMAURL="https://capima.nntoan.com"
CONTABO_BOOTBUCKET="contabo.bootscripts"

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

# Bootstrap AWS
sleep 2
BootstrapAwsCli "$@"

# Bootstrap SSH keys
sleep 2
BootstrapContaboKeys "$@"

# Bootstrap SSHD service
sleep 2
BootstrapSSHService

