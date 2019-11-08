#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# FILE: /usr/sbin/capima
# DESCRIPTION: Capima Box Manager - Everything you need to use Capima Box!
# AUTHOR: Toan Nguyen (htts://github.com/nntoan)
# VERSION: 1.0.0
# ------------------------------------------------------------------------------

# Use colors, but only if connected to a terminal, and that terminal
# supports them.
if which tput >/dev/null 2>&1; then
  ncolors=$(tput colors)
fi
if [ -t 1 ] && [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
  RED="$(tput setaf 1)"
  GREEN="$(tput setaf 2)"
  YELLOW="$(tput setaf 3)"
  BLUE="$(tput setaf 4)"
  BOLD="$(tput bold)"
  NORMAL="$(tput sgr0)"
else
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  BOLD=""
  NORMAL=""
fi

# CPM user vars
USER="capima"
HOMEDIR=$(getent passwd $USER | cut -d ':' -f6 | sed 's/\/*$//g')
WEBAPP_STACK=""
APPNAME="$$$"
APPDOMAINS=""
PUBLICPATH="current"
PHP_VERSION=""
WEBAPP_DIR="$HOMEDIR/webapps"
CAPIMAURL="https://capima.nntoan.com"
PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
PHP_EXTRA_CONFDIR="/etc/php-extra"
NGINX_CONFDIR="/etc/nginx-rc/conf.d"
APACHE_CONFDIR="/etc/apache2-rc/conf.d"

function main {
  case "$1" in
    new)
      CreateNewWebApp
    ;;
    use)
      SwitchPhpCliVersion "$2"
    ;;
    restart)
      RestartAllServices
    ;;
    logs)
      TailLogs "$2"
    ;;
    --no-ansi)
    Usage --no-ansi
    ;;
    *|help|-h|--help|--ansi)
    Usage --ansi
    ;;
  esac
}

function CreateNewWebApp {
  # Define the app name
  while [[ $APPNAME =~ [^a-z0-9] ]] || [[ $APPNAME == '' ]]
  do
    read -r -p "${BLUE}Please enter your webapp name (lowercase, alphanumeric):${NORMAL} " APPNAME
    if [[ -z "$APPNAME" ]]; then
      echo -ne "${RED}No app name entered.${NORMAL}"
      echo ""
    fi
  done
    APPDOMAINS="$APPNAME.test www.$APPNAME.test"
    echo -ne "${YELLOW}Your webapp name set to: $APPNAME"
    echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
    echo ""

  # Define the domains
  read -r -p "${BLUE}Please enter all the domain names and sub-domain names you would like to use, separated by space [$APPDOMAINS]:${NORMAL} " response
  if [[ -z "$response" ]]; then
    APPDOMAINS="$APPNAME.test www.$APPNAME.test"
  else
    APPDOMAINS="$response"
  fi
  echo -ne "${YELLOW}Domain of webapp set to: $APPDOMAINS"
  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""

  # Define the public path
  read -r -p "${BLUE}Please enter the public path of your webapp [current]:${NORMAL} " response
  if [[ -z "$response" ]]; then
    PUBLICPATH="current"
  else
    PUBLICPATH="$response"
  fi
  echo -ne "${YELLOW}The webapp path set to: $WEBAPP_DIR/$APPNAME/$PUBLICPATH"
  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""

  # Choose a web application stack
  read -r -p "${BLUE}Please choose web application stack (hybrid, nativenginx, customnginx)? [hybrid]${NORMAL} " response
  case "$response" in
    hybrid|*)
      WEBAPP_STACK="hybrid"
      echo -ne "${YELLOW}NGINX + Apache2 Hybrid (You will be able to use .htaccess)"
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
      ;;
    nativenginx)
      WEBAPP_STACK="nativenginx"
      echo -ne "${YELLOW}Native NGINX (You won't be able to use .htaccess but it is faster)"
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
      ;;
    customnginx)
      WEBAPP_STACK="customnginx"
      echo -ne "${YELLOW}Native NGINX + Custom config (For power user. Manual Nginx implementation)"
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
      ;;
  esac

  # Choose PHP version
  read -r -p "${BLUE}Please choose PHP version of your webapp? [7.3]${NORMAL} " response
  case "$response" in
    7.0)
      PHP_VERSION="php70rc"
      PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      echo -ne "${YELLOW}PHP version of webapp set to $PHP_VERSION"
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
      ;;
    7.1)
      PHP_VERSION="php71rc"
      PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      echo -ne "${YELLOW}PHP version of webapp set to $PHP_VERSION"
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
      ;;
    7.2)
      PHP_VERSION="php72rc"
      PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      echo -ne "${YELLOW}PHP version of webapp set to $PHP_VERSION"
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
      ;;
    7.3|*)
      PHP_VERSION="php73rc"
      PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      echo -ne "${YELLOW}PHP version of webapp set to $PHP_VERSION"
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
      ;;
  esac

  BootstrapWebApplication "$WEBAPP_STACK"
}

function BootstrapWebApplication {
  # Start configuring everything
  echo -ne "${YELLOW}Please wait, we are configuring your web application"

  # Creating dirs
  if [[ ! -d "$WEBAPP_DIR" ]]; then
    mkdir -p "$WEBAPP_DIR"
  fi
  if [[ ! -d "$PHP_EXTRA_CONFDIR" ]]; then
    mkdir -p "$PHP_EXTRA_CONFDIR"
  fi
  
  mkdir -p "$WEBAPP_DIR/$APPNAME/$PUBLICPATH"
  chown -Rf "$USER":"$USER" "$WEBAPP_DIR/$APPNAME"

  # Nginx
  mkdir -p $NGINX_CONFDIR/$APPNAME.d
  wget "$CAPIMAURL/templates/nginx/$1/$1.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g" > $NGINX_CONFDIR/$APPNAME.conf
  wget "$CAPIMAURL/templates/nginx/$1/$1.d/headers.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g" > $NGINX_CONFDIR/$APPNAME.d/headers.conf
  wget "$CAPIMAURL/templates/nginx/$1/$1.d/main.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g;s/APPDOMAINS/$APPDOMAINS/g;s|HOMEDIR|$HOMEDIR|g;s/PUBLICPATH/$PUBLICPATH/g" > $NGINX_CONFDIR/$APPNAME.d/main.conf
  wget "$CAPIMAURL/templates/nginx/$1/$1.d/proxy.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g" > $NGINX_CONFDIR/$APPNAME.d/proxy.conf
  
  # Apache
  if [[ "$1" == "hybrid" ]]; then
    wget "$CAPIMAURL/templates/apache/$1.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g;s/APPDOMAINS/$APPDOMAINS/g;s|HOMEDIR|$HOMEDIR|g;s/PUBLICPATH/$PUBLICPATH/g" > $APACHE_CONFDIR/$APPNAME.conf
  fi

  # PHP-FPM
  wget "$CAPIMAURL/templates/php/fpm.d/appname.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g;s|HOMEDIR|$HOMEDIR|g;s/USER/$USER/g" > $PHP_CONFDIR/$APPNAME.conf
  wget "$CAPIMAURL/templates/php/extra/appname.conf" --quiet -O $PHP_EXTRA_CONFDIR/$APPNAME.conf

  systemctl restart nginx-rc.service
  systemctl restart apache2-rc.service
  systemctl restart $PHP_VERSION-fpm.service

  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""
}

function SwitchPhpCliVersion {
  case "$1" in
    7.0|70)
      ln -sf /RunCloud/Packages/php70rc/bin/php /usr/bin/php
    ;;
    7.1|71)
      ln -sf /RunCloud/Packages/php71rc/bin/php /usr/bin/php
    ;;
    7.2|72)
      ln -sf /RunCloud/Packages/php72rc/bin/php /usr/bin/php
    ;;
    7.3|73)
      ln -sf /RunCloud/Packages/php73rc/bin/php /usr/bin/php
    ;;
  esac

  echo -ne "${YELLOW}PHP-CLI version set to: $1."
  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""
}

function RestartAllServices {
  systemctl restart nginx-rc.service
  systemctl restart apache2-rc.service
  systemctl restart php70rc-fpm.service
  systemctl restart php71rc-fpm.service
  systemctl restart php72rc-fpm.service
  systemctl restart php73rc-fpm.service
}

function TailLogs {
  case "$1" in
    nginx)
      tail -f $HOMEDIR/logs/nginx/*.log -n200
      ;;
    apache)
      tail -f $HOMEDIR/logs/apache2/*.log -n200
      ;;
    fpm)
      tail -f $HOMEDIR/logs/fpm/*.log -n200
      ;;
  esac
}

function Usage {
  case "$1" in
    --ansi)
      echo "${YELLOW}CAPIMA v1.0.0${NORMAL}"

      echo

      echo "${YELLOW}Usage:"
      echo ${NORMAL} "capima [commands] [options]"

      echo

      echo "${YELLOW}Options:${NORMAL}"
      echo ${GREEN} "--help${NORMAL}(-h)       Display this help message."
      echo ${GREEN} "--quiet${NORMAL}(-q)      Do not output any message."
      echo ${GREEN} "--ansi${NORMAL}           Force ANSI output."
      echo ${GREEN} "--no-ansi${NORMAL}        Disable ANSI output."

      echo

      echo "${YELLOW}Available commands:${NORMAL}"
      echo ${GREEN} "new${NORMAL}              Create new webapp in Capima."
      echo ${GREEN} "use${NORMAL}              Switch between version of PHP-CLI."
      echo ${GREEN} "restart${NORMAL}          Restart all Capima services."
      echo ${GREEN} "logs${NORMAL}             Tail the last 200 lines of logfile (apache,fpm,nginx)."
    ;;
    --no-ansi)
      echo "CAPIMA v1.0.0"

      echo

      echo "Usage:"
      echo " capima [commands] [options]"

      echo

      echo "Options:"
      echo " --help${NORMAL}(-h)       Display this help message."
      echo " --quiet${NORMAL}(-q)      Do not output any message."
      echo " --ansi${NORMAL}           Force ANSI output."
      echo " --no-ansi${NORMAL}        Disable ANSI output."

      echo

      echo "Available commands:"
      echo " new${NORMAL}              Create new webapp in Capima."
      echo " use${NORMAL}              Switch between version of PHP-CLI. (7.0, 7.1, 7.2, 7.3)"
      echo " restart${NORMAL}          Restart all Capima services."
      echo " logs${NORMAL}             Tail the last 200 lines of logfile (apache,fpm,nginx)."
    ;;
  esac
}

# Checker
if [[ $EUID -ne 0 ]]; then
    message="Capima must be run as root!"
    echo ${RED}$message${NORMAL} 1>&2
    exit 1
fi

main "$1"