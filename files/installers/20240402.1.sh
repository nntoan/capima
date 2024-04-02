#!/usr/bin/env bash
#
#
# Capima patcher script for Ubuntu servers
# VERSION: 20240402.1
#
# DO NOT RUN THIS SCRIPT MANUALLY UNLESS YOU KNOW WHAT YOU ARE DOING !!!
#

OSNAME=`lsb_release -s -i`
OSVERSION=`lsb_release -s -r`
OSCODENAME=`lsb_release -s -c`
PATCH_VERSION=$1
SUPPORTEDVERSION="16.04 18.04 20.04 22.04"
INSTALLPACKAGE=""
readonly SELF=$(basename "$0")

function ReplaceWholeLine {
    sed -i "s/$1.*/$2/" $3
}

function ReplaceTrueWholeLine {
    sed -i "s/.*$1.*/$2/" $3
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

function PatchingServer {
    echo -ne "Patching the server..."

    if [[ ! -d "/opt/Capima/patched" ]]; then
      mkdir -p /opt/Capima/patched;
    fi

    if [[ ! -f "/opt/Capima/patched/$PATCH_VERSION" ]]; then
      touch "/opt/Capima/patched/$PATCH_VERSION";
    else
      echo -ne "Server already patched. Exiting...\n"
      exit 0
    fi
}

# Checker
if [[ $EUID -ne 0 ]]; then
    message="Capima patcher must be run as root!"
    echo $message 1>&2
    exit 1
fi

if [[ "$OSNAME" != "Ubuntu" ]]; then
    message="This patcher only support $OSNAME"
    echo $message
    exit 1
fi

if [[ $(uname -m) != "x86_64" ]]; then
    message="This patcher only support x86_64 architecture"
    echo $message
    exit 1
fi

grep -q $OSVERSION <<< $SUPPORTEDVERSION
if [[ $? -ne 0 ]]; then
    message="This patcher does not support $OSNAME $OSVERSION"
    echo $message
    exit 1
fi

CAPIMAURL="https://capima.nntoan.com"

locale-gen en_US en_US.UTF-8

export LANGUAGE=en_US.utf8
export LC_ALL=en_US.utf8
export DEBIAN_FRONTEND=noninteractive

# Checking if server is up
CheckingRemoteAccessible

# Patch the server
PatchingServer