#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# FILE: /usr/sbin/capima
# DESCRIPTION: Capima Box Manager - Everything you need to use Capima Box!
# AUTHOR: Toan Nguyen (htts://github.com/nntoan)
# VERSION: 1.0.5
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

# Global issues
OSNAME=`lsb_release -s -i`
OSVERSION=`lsb_release -s -r`
OSCODENAME=`lsb_release -s -c`
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
LATEST_VERSION="$(curl --silent https://capima.nntoan.com/files/scripts/capima.version)"
# Read-only variables
readonly VERSION="1.0.6"
readonly SELF=$(basename "$0")
readonly UPDATE_BASE="${CAPIMAURL}/files/scripts"
readonly PHP_EXTRA_CONFDIR="/etc/php-extra"
readonly NGINX_CONFDIR="/etc/nginx-rc/conf.d"
readonly APACHE_CONFDIR="/etc/apache2-rc/conf.d"
readonly CAPIMA_LOGFILE="/var/log/capima.log"

function main {
  case "$1" in
    web)
      WebAppsManagement "$@"
    ;;
    use)
      SwitchPhpCliVersion "$@"
    ;;
    enable)
      EnableServices "$@"
    ;;
    restart)
      RestartServices "$@"
    ;;
    info)
      GetWebAppInfo "$@"
    ;;
    logs)
      TailLogs "$@"
    ;;
    self-update|selfupdate)
      UpdateSelfAndInvoke "$@"
    ;;
    --no-ansi)
      Usage --no-ansi
    ;;
    --version|-v)
      ShowCurrentVersion
    ;;
    *|help|-h|--help|--ansi)
      Usage --ansi
    ;;
  esac
}

function WebAppsManagement {
  Heading

  if [[ -z "$2" ]]; then
    # Must-choose an option
    while true; do
      read -r -p "${BLUE}Please select an action you would like to take [add|update|delete]:${NORMAL} " action
      case "$action" in
        exit|q|x) break ;;
        add|new|a)
          CreateNewWebApp
        ;;
        update|u)
          UpdateWebApp
        ;;
        delete|remove|del|d)
          DeleteWebApp
        ;;
        *)
          echo "${RED}Unknown response, please select an action you would like to take: add(a), update(u), delete(d) or type 'exit' (q, x) to quit.${NORMAL}"
        ;;
      esac
    done
  else
    case "$2" in
      add)
        CreateNewWebApp
      ;;
      update)
        UpdateWebApp
      ;;
      delete)
        DeleteWebApp
      ;;
      *)
        echo "${RED}Unknown action, please try again with one of the following action: add, update, delete.${NORMAL}"
      ;;
    esac
  fi
}

function CreateNewWebApp {
  # Define the app name
  while [[ $APPNAME =~ [^-a-z0-9] ]] || [[ $APPNAME == '' ]]
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
    hybrid|*)
      WEBAPP_STACK="hybrid"
      echo -ne "${YELLOW}NGINX + Apache2 Hybrid (You will be able to use .htaccess)"
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
      ;;
  esac

  # Choose PHP version
  read -r -p "${BLUE}Please choose PHP version of your webapp? [7.3]${NORMAL} " response
  case "$response" in
    5.5|55)
      PHP_VERSION="php55rc"
      PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      ;;
    5.6|56)
      PHP_VERSION="php56rc"
      PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      ;;
    7.0|70)
      PHP_VERSION="php70rc"
      PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      ;;
    7.1|71)
      PHP_VERSION="php71rc"
      PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      ;;
    7.2|72)
      PHP_VERSION="php72rc"
      PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      ;;
    7.3|73|*)
      PHP_VERSION="php73rc"
      PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      ;;
  esac

  echo -ne "${YELLOW}PHP version of webapp set to $PHP_VERSION"
  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""

  BootstrapWebApplication "$WEBAPP_STACK"
  exit
}

function UpdateWebApp {
  echo "${YELLOW}This functionality is being under development... Please try again next year.${NORMAL}"
}

function DeleteWebApp {
  # Define the app name
  while [[ $appname =~ [^a-z0-9] ]] || [[ $appname == '' ]]
  do
    read -r -p "${BLUE}Please enter the webapp name you would like to delete:${NORMAL} " appname
    if [[ -z "$appname" ]]; then
      echo -ne "${RED}No app name entered.${NORMAL}"
      echo ""
    fi
  done

  echo -ne "${YELLOW}Please wait, we are removing your web application...${NORMAL}"
  rm -rf $WEBAPP_DIR/$appname
  rm -rf $NGINX_CONFDIR/$appname.conf
  rm -rf $NGINX_CONFDIR/$appname.d
  rm -rf $APACHE_CONFDIR/$appname.conf
  rm -rf $PHP_CONFDIR/$appname.conf
  rm -rf $PHP_EXTRA_CONFDIR/$appname.conf
  sed -i "/$appname/d" $CAPIMA_LOGFILE

  systemctl restart nginx-rc.service
  systemctl restart apache2-rc.service
  if [[ "$OSCODENAME" == 'xenial' ]]; then
    systemctl restart php55rc-fpm.service
    systemctl restart php56rc-fpm.service
  fi
  systemctl restart php70rc-fpm.service
  systemctl restart php71rc-fpm.service
  systemctl restart php72rc-fpm.service
  systemctl restart php73rc-fpm.service
  echo -ne "${YELLOW}...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""

  exit
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

  # Writing to logfile
  echo -ne "$APPNAME:" >> $CAPIMA_LOGFILE
  echo -ne "$APPDOMAINS:" >> $CAPIMA_LOGFILE
  echo -ne "$PHP_VERSION:" >> $CAPIMA_LOGFILE
  echo -ne "$PUBLICPATH:" >> $CAPIMA_LOGFILE
  echo -ne "$WEBAPP_DIR/$APPNAME:" >> $CAPIMA_LOGFILE

  # Nginx
  mkdir -p $NGINX_CONFDIR/$APPNAME.d
  wget "$CAPIMAURL/templates/nginx/$1/$1.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g" > $NGINX_CONFDIR/$APPNAME.conf
  wget "$CAPIMAURL/templates/nginx/$1/$1.d/headers.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g" > $NGINX_CONFDIR/$APPNAME.d/headers.conf
  wget "$CAPIMAURL/templates/nginx/$1/$1.d/main.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g;s/APPDOMAINS/$APPDOMAINS/g;s|HOMEDIR|$HOMEDIR|g;s/PUBLICPATH/$PUBLICPATH/g" > $NGINX_CONFDIR/$APPNAME.d/main.conf
  wget "$CAPIMAURL/templates/nginx/$1/$1.d/proxy.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g" > $NGINX_CONFDIR/$APPNAME.d/proxy.conf
  echo -ne "$NGINX_CONFDIR/$APPNAME.conf:" >> $CAPIMA_LOGFILE
  echo -ne "$NGINX_CONFDIR/$APPNAME.d:" >> $CAPIMA_LOGFILE
  
  # Apache
  if [[ "$1" == "hybrid" ]]; then
    wget "$CAPIMAURL/templates/apache/$1.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g;s/APPDOMAINS/$APPDOMAINS/g;s|HOMEDIR|$HOMEDIR|g;s/PUBLICPATH/$PUBLICPATH/g" > $APACHE_CONFDIR/$APPNAME.conf
    echo -ne "$APACHE_CONFDIR/$APPNAME.conf:" >> $CAPIMA_LOGFILE
  fi

  # PHP-FPM
  wget "$CAPIMAURL/templates/php/fpm.d/appname.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g;s|HOMEDIR|$HOMEDIR|g;s/USER/$USER/g" > $PHP_CONFDIR/$APPNAME.conf
  wget "$CAPIMAURL/templates/php/extra/appname.conf" --quiet -O $PHP_EXTRA_CONFDIR/$APPNAME.conf
  echo -ne "$PHP_CONFDIR/$APPNAME.conf:" >> $CAPIMA_LOGFILE
  echo -ne "$PHP_EXTRA_CONFDIR/$APPNAME.conf" >> $CAPIMA_LOGFILE
  echo "" >> $CAPIMA_LOGFILE

  systemctl restart nginx-rc.service
  systemctl restart apache2-rc.service
  systemctl restart $PHP_VERSION-fpm.service

  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""
}

function SwitchPhpCliVersion {
  case "$2" in
    5.5|55)
      ln -sf /RunCloud/Packages/php55rc/bin/php /usr/bin/php
    ;;
    5.6|56)
      ln -sf /RunCloud/Packages/php56rc/bin/php /usr/bin/php
    ;;
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

  echo -ne "${YELLOW}PHP-CLI version set to: $2."
  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""
}

function EnableServices {
  case "$2" in
    elasticsearch)
      systemctl enable elasticsearch.service
      systemctl restart elasticsearch.service
    ;;
    redis)
      systemctl enable redis-server
      systemctl restart redis-server
    ;;
    *)
      echo "${RED}Please choose at least a service you would like to enable: elasticsearch, redis.${NORMAL}"
    ;;
  esac
}

function RestartServices {
  case "$2" in
    nginx)
      systemctl restart nginx-rc.service
    ;;
    apache)
      systemctl restart apache2-rc.service
    ;;
    php)
      if [[ "$OSCODENAME" == 'xenial' ]]; then
        systemctl restart php55rc-fpm.service
        systemctl restart php56rc-fpm.service
      fi
      systemctl restart php70rc-fpm.service
      systemctl restart php71rc-fpm.service
      systemctl restart php72rc-fpm.service
      systemctl restart php73rc-fpm.service
    ;;
    elastic)
      systemctl restart elasticsearch.service
    ;;
    redis)
      systemctl restart redis-server.service
    ;;
    mailhog)
      systemctl restart mailhog.service
    ;;
    *|all|--all|-a)
      systemctl restart nginx-rc.service
      systemctl restart apache2-rc.service
      if [[ "$OSCODENAME" == 'xenial' ]]; then
        systemctl restart php55rc-fpm.service
        systemctl restart php56rc-fpm.service
      fi
      systemctl restart php70rc-fpm.service
      systemctl restart php71rc-fpm.service
      systemctl restart php72rc-fpm.service
      systemctl restart php73rc-fpm.service
      systemctl restart elasticsearch.service
      systemctl restart redis-server.service
      systemctl restart mailhog.service
    ;;
  esac
}

function GetListAllWebApps {
  echo $(ls -1 ${PHP_EXTRA_CONFDIR} | sed -e 's/\..*$//')
}

function GetWebAppInfo {
  current_dir=$(pwd)
  all_webapps=$(ls -1 ${PHP_EXTRA_CONFDIR} | sed -e 's/\..*$//')
  available_apps=(${all_webapps// /})

  # Run automatically check
  if [[ -z "$2" ]]; then
    for i in "${!available_apps[@]}"
    do
      if [[ "$current_dir" == *"${available_apps[i]}"* ]]; then
        echo "${BLUE}Your webapp name is: ${available_apps[i]}${NORMAL}"
        echo "${BLUE}Your nginx config path is located at: $NGINX_CONFDIR/${available_apps[i]}.conf${NORMAL}"
      fi
    done
  else
    echo "${RED}Sorry, we unable to detect your webapps. Please change directory to your webapp then try again.${NORMAL}"
  fi
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
    all|*)
      tail -f $HOMEDIR/logs/nginx/*.log $HOMEDIR/logs/apache2/*.log $HOMEDIR/logs/fpm/*.log -n200
      ;;
  esac
}

function ShowCurrentVersion {
  echo ${GREEN}Capima is running on${NORMAL} ${YELLOW}v${VERSION}${NORMAL}.
}

function ShowLatestVersion {
  echo ${GREEN}The latest version of Capima is${NORMAL} ${YELLOW}v${LATEST_VERSION}${NORMAL}.
}

function VersionCheck {
  dpkg --compare-versions "$VERSION" "lt" "$LATEST_VERSION"
  if [[ "$?" -eq 0 ]]; then
    return 0
  else
    return 999
  fi
}

function UpdateSelfAndInvoke {
  ShowCurrentVersion
  echo "${GREEN}Checking if on latest version...${NORMAL}"
  VersionCheck
  if [[ "$?" -eq 0 ]]; then
    ShowLatestVersion

    # Download new version
    echo -ne "${GREEN}Downloading latest version...${NORMAL}"
    if ! wget --quiet --output-document="$0.tmp" "$UPDATE_BASE/$SELF.sh" ; then
      echo "${RED}Failed: Error while trying to download new version!${NORMAL}"
      echo "${YELLOW}File requested: $UPDATE_BASE/$SELF.sh${NORMAL}"
      exit 1
    fi
    echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
    echo ""

    echo -ne "${GREEN}Performing self-update...${NORMAL}"
    # Copy over modes from old version
    OCTAL_MODE=$(stat -c '%a' $0)
    chmod $OCTAL_MODE $0.tmp

    # Overwrite old file with new
    mv $0.tmp $0
    echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL} 🎉🎉🎉"
    echo ""

    exit 0
  fi
}

function Heading {
  echo "${BLUE}

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

Made with ♥ by Toan Nguyen (v${VERSION})

${NORMAL}"
}

function Usage {
  case "$1" in
    --ansi)
      echo "${YELLOW}CAPIMA v${VERSION}${NORMAL}"

      echo

      echo "${YELLOW}Usage:"
      echo ${NORMAL} "capima [commands] [options]"

      echo

      echo "${YELLOW}Options:${NORMAL}"
      echo ${GREEN} "--version${NORMAL}(-v)    Display current version."
      echo ${GREEN} "--help${NORMAL}(-h)       Display this help message."
      echo ${GREEN} "--quiet${NORMAL}(-q)      Do not output any message."
      echo ${GREEN} "--ansi${NORMAL}           Force ANSI output."
      echo ${GREEN} "--no-ansi${NORMAL}        Disable ANSI output."

      echo

      echo "${YELLOW}Available commands:${NORMAL}"
      echo ${GREEN} "web${NORMAL}              Webapps management panel (add/update/delete)."
      echo ${GREEN} "use${NORMAL}              Switch between version of PHP-CLI."
      echo ${GREEN} "restart${NORMAL}          Restart Capima services."
      echo ${GREEN} "info${NORMAL}             Show webapps information (under development)."
      echo ${GREEN} "logs${NORMAL}             Tail the last 200 lines of logfile (apache,fpm,nginx)."
      echo ${GREEN} "self-update${NORMAL}      Check latest version and performing self-update."
    ;;
    --no-ansi)
      echo "CAPIMA v${VERSION}"

      echo

      echo "Usage:"
      echo " capima [commands] [options]"

      echo

      echo "Options:"
      echo " --version${NORMAL}(-v)    Display current version."
      echo " --help${NORMAL}(-h)       Display this help message."
      echo " --quiet${NORMAL}(-q)      Do not output any message."
      echo " --ansi${NORMAL}           Force ANSI output."
      echo " --no-ansi${NORMAL}        Disable ANSI output."

      echo

      echo "Available commands:"
      echo " web${NORMAL}              Webapps management panel (add/update/delete)."
      echo " use${NORMAL}              Switch between version of PHP-CLI. (7.0, 7.1, 7.2, 7.3)"
      echo " restart${NORMAL}          Restart Capima services."
      echo " info${NORMAL}             Show webapps information (under development)."
      echo " logs${NORMAL}             Tail the last 200 lines of logfile (apache,fpm,nginx)."
      echo " self-update${NORMAL}      Check latest version and performing self-update."
    ;;
  esac
}

# Checker
if [[ $EUID -ne 0 ]]; then
  message="Capima must be run as root!"
  echo ${RED}$message${NORMAL} 1>&2
  exit 1
fi

main "$@"