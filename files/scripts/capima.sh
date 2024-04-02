#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# FILE: /usr/sbin/capima
# DESCRIPTION: Capima Box Manager - Everything you need to use Capima Box!
# AUTHOR: Toan Nguyen (htts://github.com/nntoan)
# VERSION: 1.4.3
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
MAGE_MODE=""
APPNAME="$$$"
DBNAME="$$$"
APPDOMAINS=""
APPDOMAINS_CRT=""
APPDOMAINS_LE=""
PUBLICPATH="current"
PHP_VERSION=""
PHP_SWITCHED="X"
MNTWEB="/mnt/web/production"
WEBAPP_DIR="$HOMEDIR/webapps"
CERTDIR="/opt/Capima/certificates"
SECURED_WEBAPP="X"
SECURED_LIVE="X"
USE_CAPICACHE="X"
CAPIMAURL="https://capima.nntoan.com"
PHP_CONFDIR="/etc/$PHP_VERSION/conf.d"
PHP_FPMDIR="/etc/$PHP_VERSION/fpm.d"
LE_EMAIL=""
CERTBOT_AUTO="/usr/local/bin/certbot-auto"
SECURED_KEYFILE="$CERTDIR/$APPNAME/privkey.pem"
SECURED_CONFFILE="$CERTDIR/$APPNAME/openssl.conf"
SECURED_CRTFILE="$CERTDIR/$APPNAME/fullchain.pem"
SECURED_CSRFILE="$CERTDIR/$APPNAME/$APPNAME.csr"
LATEST_VERSION="$(curl --silent https://capima.nntoan.com/files/scripts/capima.version)"
# Read-only variables
declare -A ACTUAL_SERVICE=(
  ["nginx"]="nginx-rc.service"
  ["apache"]="apache2-rc.service"
  ["php55"]="php55rc-fpm.service"
  ["php56"]="php56rc-fpm.service"
  ["php70"]="php70rc-fpm.service"
  ["php71"]="php71rc-fpm.service"
  ["php72"]="php72rc-fpm.service"
  ["php73"]="php73rc-fpm.service"
  ["php74"]="php74rc-fpm.service"
  ["php80"]="php80rc-fpm.service"
  ["php81"]="php81rc-fpm.service"
  ["php82"]="php82rc-fpm.service"
  ["php83"]="php83rc-fpm.service"
  ["mysql"]="mariadb.service"
  ["redis"]="redis-server.service"
  ["elasticsearch"]="elasticsearch.service"
  ["opensearch"]="opensearch.service"
  ["mailhog"]="mailhog.service"
)
declare -A PHP_PATHS=(
  ["php55"]="/RunCloud/Packages/php55rc"
  ["php56"]="/RunCloud/Packages/php56rc"
  ["php70"]="/RunCloud/Packages/php70rc"
  ["php71"]="/RunCloud/Packages/php71rc"
  ["php72"]="/RunCloud/Packages/php72rc"
  ["php73"]="/RunCloud/Packages/php73rc"
  ["php74"]="/RunCloud/Packages/php74rc"
  ["php80"]="/RunCloud/Packages/php80rc"
  ["php81"]="/RunCloud/Packages/php81rc"
  ["php82"]="/RunCloud/Packages/php82rc"
  ["php83"]="/RunCloud/Packages/php83rc"
)
declare -A PHPFPM_CONFDIRS=(
  ["php55"]="/etc/php55rc/fpm.d"
  ["php56"]="/etc/php56rc/fpm.d"
  ["php70"]="/etc/php70rc/fpm.d"
  ["php71"]="/etc/php71rc/fpm.d"
  ["php72"]="/etc/php72rc/fpm.d"
  ["php73"]="/etc/php73rc/fpm.d"
  ["php74"]="/etc/php74rc/fpm.d"
  ["php80"]="/etc/php80rc/fpm.d"
  ["php81"]="/etc/php81rc/fpm.d"
  ["php82"]="/etc/php82rc/fpm.d"
  ["php83"]="/etc/php83rc/fpm.d"
)
readonly VERSION="1.4.3"
readonly PATCH_VERSION="20240402.1"
readonly SELF=$(basename "$0")
readonly UPDATE_BASE="${CAPIMAURL}/files/scripts"
readonly PHP_EXTRA_CONFDIR="/etc/php-extra"
readonly NGINX_CONFDIR="/etc/nginx-rc/conf.d"
readonly NGINX_EXTRA_CONFDIR="/etc/nginx-rc/extra.d"
readonly APACHE_CONFDIR="/etc/apache2-rc/conf.d"
readonly CAPIMA_LOGFILE="/var/log/capima.log"

# Services detection
SERVICES=$(systemctl --type=service --state=active | grep -E '\.service' | cut -d ' ' -f1 | sed -r 's/.{8}$//' | tr '\n' ' ')
DETECTEDSERVICESCOUNT=0
DETECTEDSERVICESNAME=""

function main {
  case "$1" in
    web)
      WebAppsManagement "$@"
    ;;
    db)
      DatabasesManagement "$@"
    ;;
    use)
      SwitchPhpCliVersion "$@"
    ;;
    enable)
      EnableServices "$@"
    ;;
    disable)
      DisableServices "$@"
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
        list|ls)
          ListWebApps
        ;;
        *)
          echo "${RED}Unknown response, please select an action you would like to take: add(a), update(u), delete(d), list(ls) or type 'exit' (q, x) to quit.${NORMAL}"
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
      list|ls)
        ListWebApp
      ;;
      *)
        echo "${RED}Unknown action, please try again with one of the following action: add, update, delete, list.${NORMAL}"
      ;;
    esac
  fi
}

function DatabasesManagement {
  Heading

  if [[ -z "$2" ]]; then
    # Must-choose an option
    while true; do
      read -r -p "${BLUE}Please select an action you would like to take [add|update|delete|import]:${NORMAL} " action
      case "$action" in
        exit|q|x) break ;;
        add|new|a)
          CreateNewDb
        ;;
        update|u)
          UpdateDb
        ;;
        delete|remove|del|d)
          DeleteDb
        ;;
        import|i)
          ImportDb
        ;;
        *)
          echo "${RED}Unknown response, please select an action you would like to take: add(a), update(u), delete(d), import(i) or type 'exit' (q, x) to quit.${NORMAL}"
        ;;
      esac
    done
  else
    case "$2" in
      add)
        CreateNewDb
      ;;
      update)
        UpdateDb
      ;;
      delete)
        DeleteDb
      ;;
      import)
        ImportDb
      ;;
      *)
        echo "${RED}Unknown action, please try again with one of the following action: add, update, delete, import.${NORMAL}"
      ;;
    esac
  fi
}

function CreateNewWebApp {
  # Make request to server
  CheckingRemoteAccessible

  # Define the app name
  local randomName=$(petname --complexity 2 --words 1)
  local randomAppName="app-${randomName}"
  while [[ $APPNAME =~ [^-a-z0-9] ]] || [[ $APPNAME == '' ]]
  do
    read -r -p "${BLUE}Please enter your webapp name (lowercase, alphanumeric) [$randomAppName]:${NORMAL} " APPNAME
    if [[ -z "$APPNAME" ]]; then
      APPNAME="$randomAppName"
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
  APPDOMAINS_CRT=($APPDOMAINS)
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
  read -r -p "${BLUE}Please choose web application stack (hybrid, nativenginx, magenx, customnginx)? [hybrid]${NORMAL} " response
  case "$response" in
    nativenginx)
      WEBAPP_STACK="nativenginx"
      echo -ne "${YELLOW}Native NGINX (You won't be able to use .htaccess but it is faster)"
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
      ;;
    magenx)
      WEBAPP_STACK="magenx"
      echo -ne "${YELLOW}Magento 2 NGINX (Pre-configured for production-grade Magento 2 application)"
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

  if [[ "$WEBAPP_STACK" == "magenx" ]]; then
    # Set Magento Mode
    read -r -p "${BLUE}Which deploy mode you would like to setup (developer, production)? [production]${NORMAL} " response
    case "$response" in
      developer|dev)
        MAGE_MODE="developer"
        echo -ne "${YELLOW}Your Magento application mode has been set to ${MAGE_MODE}"
        echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
        echo ""
        ;;
      production|prod|*)
        MAGE_MODE="production"
        echo -ne "${YELLOW}Your Magento application mode has been set to ${MAGE_MODE}"
        echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
        echo ""
        ;;
    esac
  fi

  # Enable FastCGI Cache for webapp
  read -r -p "${BLUE}Do you want to enable Nginx FastCGI Cache for your webapp? [Y/N]${NORMAL} " response
  case "$response" in
    [yY][eE][sS]|[yY])
      USE_CAPICACHE="Y"
      echo -ne "${YELLOW}Your web application will use FastCGI Cache. For more information, please visit: https://runcloud.io/blog/nginx-fastcgi-cache/"
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
      ;;
    [nN][oO]|[nN]|*)
      USE_CAPICACHE="N"
      echo -ne "${YELLOW}Ok, skipping...${NORMAL}"
      echo ""
      ;;
  esac

  # Enable SSL for webapp
  read -r -p "${BLUE}Do you want to enable SSL for your webapp (dev,live,skip)? [dev]${NORMAL} " response
  case "$response" in
    skip)
      SECURED_WEBAPP="N"
      echo -ne "${YELLOW}Ok, skipping...${NORMAL}"
      echo ""
      ;;
    live)
      SECURED_WEBAPP="Y"
      SECURED_LIVE="Y"
      le=$(dpkg-query -W letsencrypt 2>/dev/null)
      echo -ne "${YELLOW}Configuring SSL certificates for Let's Encrypt..."
      if [[ "$OSCODENAME" == 'xenial' ]]; then
        if [[ ! -f "$CERTBOT_AUTO" ]]; then
          echo ""
          read -r -p "${BLUE}Let's Encrypt is not installed/found. Would you like to install it? [Y/N]${NORMAL} " response
          case "$response" in
            [nN][oO]|[nN])
              echo -ne "${YELLOW}Ok, skipping...${NORMAL}"
              echo ""
            ;;
            [yY][eE][sS]|[yY]|*)
              echo -ne "${YELLOW}Installing Let's Encrypt...${NORMAL}"
              git clone https://github.com/certbot/certbot.git /opt/Capima/certbot &>/dev/null
              ln -sf /opt/Capima/certbot/certbot-auto /usr/local/bin/certbot-auto
              echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
              echo ""
            ;;
          esac
        fi
      else
        if [[ "$le" != 'letsencrypt' ]]; then
          echo ""
          read -r -p "${BLUE}Let's Encrypt is not installed/found. Would you like to install it? [Y/N]${NORMAL} " response
          case "$response" in
            [nN][oO]|[nN])
              echo -ne "${YELLOW}Ok, skipping...${NORMAL}"
              echo ""
            ;;
            [yY][eE][sS]|[yY]|*)
              echo -ne "${YELLOW}Installing Let's Encrypt...${NORMAL}"
              apt-get update -qq
              apt-get install letsencrypt -y -qq
              echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
              echo ""
            ;;
          esac
        fi
      fi

      # Configuring variables
      for domain in $APPDOMAINS; do
        APPDOMAINS_LE+=("-d $domain")
      done
      CERTDIR="/etc/letsencrypt/live"
      SECURED_KEYFILE="$CERTDIR/${APPDOMAINS_CRT[0]}/privkey.pem"
      SECURED_CRTFILE="$CERTDIR/${APPDOMAINS_CRT[0]}/fullchain.pem"
      read -r -p "${BLUE}Enter the email you would like to register with EFF?${NORMAL} " LE_EMAIL

      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
      ;;
    dev|local|*)
      SECURED_WEBAPP="Y"
      echo -ne "${YELLOW}Configuring SSL certificates..."
      if [[ ! -d "$CERTDIR/${APPDOMAINS_CRT[0]}" ]]; then
        mkdir -p "$CERTDIR/${APPDOMAINS_CRT[0]}"
      fi
      SECURED_KEYFILE="$CERTDIR/${APPDOMAINS_CRT[0]}/privkey.pem"
      SECURED_CONFFILE="$CERTDIR/${APPDOMAINS_CRT[0]}/openssl.conf"
      SECURED_CRTFILE="$CERTDIR/${APPDOMAINS_CRT[0]}/fullchain.pem"
      SECURED_CSRFILE="$CERTDIR/${APPDOMAINS_CRT[0]}/$APPNAME.csr"

      # Downloading config file
      wget "$CAPIMAURL/templates/openssl/openssl.conf" --quiet -O - | sed "s/APPDOMAIN/${APPDOMAINS_CRT[0]}/g" > $SECURED_CONFFILE

      openssl genrsa -out $SECURED_KEYFILE 4096
      openssl req -new -key $SECURED_KEYFILE -out $SECURED_CSRFILE -subj "/C=VN/ST=HN/O=IT/localityName=Hanoi/commonName=*.${APPDOMAINS_CRT[0]}/organizationalUnitName=Capima/emailAddress=capima@nntoan.com/" -config $SECURED_CONFFILE -passin pass:
      openssl x509 -req -days 3650 -in $SECURED_CSRFILE -signkey $SECURED_KEYFILE -out $SECURED_CRTFILE -extensions v3_req -extfile $SECURED_CONFFILE

      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
      ;;
  esac

  # Choose PHP version
  read -r -p "${BLUE}Please choose PHP version of your webapp? [7.4]${NORMAL} " response
  case "$response" in
    5.5|55|5.6|56)
      if [[ "$OSCODENAME" == 'xenial' ]]; then
        PHP_VERSION=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$response")
        PHP_FPMDIR="${PHPFPM_CONFDIRS[$PHP_VERSION]}"
      else
        echo -ne "${YELLOW}Your OS version doesn't support this PHP version, fallback to default option"
        PHP_VERSION="php74rc"
        PHP_FPMDIR="/etc/$PHP_VERSION/fpm.d"
      fi
      ;;
    7.0|70|7.1|71)
      if [[ "$OSCODENAME" == 'bionic' ]]; then
        PHP_VERSION=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$response")
        PHP_FPMDIR="${PHPFPM_CONFDIRS[$PHP_VERSION]}"
      else
        echo -ne "${YELLOW}Your OS version doesn't support this PHP version, fallback to default option"
        PHP_VERSION="php74rc"
        PHP_FPMDIR="/etc/$PHP_VERSION/fpm.d"
      fi
      ;;
    7.2|72|7.3|73)
      if [[ "$OSCODENAME" == 'focal' ]]; then
        PHP_VERSION=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$response")
        PHP_FPMDIR="${PHPFPM_CONFDIRS[$PHP_VERSION]}"
      else
        echo -ne "${YELLOW}Your OS version doesn't support this PHP version, fallback to default option"
        PHP_VERSION="php74rc"
        PHP_FPMDIR="/etc/$PHP_VERSION/fpm.d"
      fi
      ;;
    8.0|80|8.1|81|8.2|82|8.3|83)
      PHP_VERSION=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$response")
      PHP_FPMDIR="${PHPFPM_CONFDIRS[$PHP_VERSION]}"
      ;;
    7.4|74|*)
      PHP_VERSION="php74"
      PHP_FPMDIR="${PHPFPM_CONFDIRS[$PHP_VERSION]}"
      ;;
  esac

  echo -ne "${YELLOW}PHP version of webapp set to $PHP_VERSION"
  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""

  BootstrapWebApplication "$WEBAPP_STACK"
  exit
}

function ListWebApp {
  echo "${YELLOW}This functionality is being under development... Please try again next year.${NORMAL}"
}

function UpdateWebApp {

  # Define the webapp name
  local $appname;
  local $response;
  while [[ $appname =~ [^-a-z0-9] ]] || [[ $appname == '' ]]
  do
    read -r -p "${BLUE}Please enter the webapp name you would like to update:${NORMAL} " appname
    if [[ -z "$appname" ]]; then
      echo -ne "${RED}No app name entered.${NORMAL}"
      echo ""
    fi
  done

  # Enable FastCGI Cache for webapp
  read -r -p "${BLUE}Do you want to enable Nginx FastCGI Cache for your webapp? [Y/N]${NORMAL} " response
  case "$response" in
    [yY][eE][sS]|[yY])
      USE_CAPICACHE="Y"
      echo -ne "${YELLOW}Your web application will use FastCGI Cache. For more information, please visit: https://runcloud.io/blog/nginx-fastcgi-cache/"
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
      ;;
    [nN][oO]|[nN]|*)
      USE_CAPICACHE="N"
      echo -ne "${YELLOW}Ok, skipping...${NORMAL}"
      echo ""
      ;;
  esac

  # Switch PHP version for webapp
  read -r -p "${BLUE}Do you want to switch PHP version for your webapp? [skip]${NORMAL} " response
  case "$response" in
    5.5|55|5.6|56)
      if [[ "$OSCODENAME" == 'xenial' ]]; then
        PHP_VERSION=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$response")
        PHP_FPMDIR="${PHPFPM_CONFDIRS[$PHP_VERSION]}"
        PHP_SWITCHED="Y"
      else
        echo -ne "${YELLOW}Your OS version doesn't support this PHP version, skipping..."
        echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
        PHP_SWITCHED="N"
      fi
      ;;
    7.0|70|7.1|71)
      if [[ "$OSCODENAME" == 'bionic' ]]; then
        PHP_VERSION=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$response")
        PHP_FPMDIR="${PHPFPM_CONFDIRS[$PHP_VERSION]}"
        PHP_SWITCHED="Y"
      else
        echo -ne "${YELLOW}Your OS version doesn't support this PHP version, skipping..."
        echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
        PHP_SWITCHED="N"
      fi
      ;;
    7.2|72|7.3|73)
      if [[ "$OSCODENAME" == 'focal' ]]; then
        PHP_VERSION=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$response")
        PHP_FPMDIR="${PHPFPM_CONFDIRS[$PHP_VERSION]}"
        PHP_SWITCHED="Y"
      else
        echo -ne "${YELLOW}Your OS version doesn't support this PHP version, skipping..."
        echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
        PHP_SWITCHED="N"
      fi
      ;;
    7.4|74|8.0|80|8.1|81|8.2|82|8.3|83)
      PHP_VERSION=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$response")
      PHP_FPMDIR="${PHPFPM_CONFDIRS[$PHP_VERSION]}"
      PHP_SWITCHED="Y"
      ;;
    skip|*)
      echo -ne "${YELLOW}Ok, skipping...${NORMAL}"
      echo ""
      PHP_SWITCHED="N"
      ;;
  esac

  # FastCGI Cache
  if [[ "$USE_CAPICACHE" == "Y" ]]; then
    if [[ -f "$NGINX_EXTRA_CONFDIR/$appname.headers.capima-hub.conf" ]]; then
      echo -ne "${YELLOW}Please wait, we are configuring your web application...${NORMAL}"

      wget "$CAPIMAURL/templates/nginx/capimacache/headers.d/fcgicache.conf" --quiet -O - | sed "s/APPNAME/$appname/g" > $NGINX_EXTRA_CONFDIR/$appname.headers.capima-hub.conf
      wget "$CAPIMAURL/templates/nginx/capimacache/location.d/fcgicache_http.conf" --quiet -O - | sed "s/APPNAME/$appname/g" > $NGINX_EXTRA_CONFDIR/$appname.location.http.capima-hub.conf
      wget "$CAPIMAURL/templates/nginx/capimacache/location.d/fcgicache_main_before.conf" --quiet -O - | sed "s/APPNAME/$appname/g" > $NGINX_EXTRA_CONFDIR/$appname.location.main-before.capima-hub.conf
      wget "$CAPIMAURL/templates/nginx/capimacache/location.d/fcgicache_proxy.conf" --quiet -O - | sed "s/APPNAME/$appname/g" > $NGINX_EXTRA_CONFDIR/$appname.location.proxy.capima-hub.conf
      echo -ne "$NGINX_EXTRA_CONFDIR/$appname.headers.capima-hub.conf:" >> $CAPIMA_LOGFILE
      echo -ne "$NGINX_EXTRA_CONFDIR/$appname.location.http.capima-hub.conf:" >> $CAPIMA_LOGFILE
      echo -ne "$NGINX_EXTRA_CONFDIR/$appname.location.main-before.capima-hub.conf:" >> $CAPIMA_LOGFILE
      echo -ne "$NGINX_EXTRA_CONFDIR/$appname.location.proxy.capima-hub.conf:" >> $CAPIMA_LOGFILE

      echo -ne "${YELLOW}...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
      RestartServices nginx
    else
      echo -ne "${YELLOW}${appname} has configured Capima Cache already...${NORMAL}"
      echo -ne "${YELLOW}...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
    fi
  fi

  # PHP-FPM
  if [[ "$PHP_SWITCHED" == "Y" ]]; then
    rm -rf /etc/php*rc/fpm.d/$appname.conf 2>&1
    rm -rf $PHP_EXTRA_CONFDIR/$appname.conf 2>&1
    wget "$CAPIMAURL/templates/php/fpm.d/appname.conf" --quiet -O - | sed "s/APPNAME/$appname/g;s|HOMEDIR|$HOMEDIR|g;s/USER/$USER/g" > $PHP_FPMDIR/$appname.conf
    wget "$CAPIMAURL/templates/php/extra/appname.conf" --quiet -O $PHP_EXTRA_CONFDIR/$appname.conf
    RestartServices php
    #echo -ne "$PHP_FPMDIR/$appname.conf:" >> $CAPIMA_LOGFILE
    #echo -ne "$PHP_EXTRA_CONFDIR/$appname.conf" >> $CAPIMA_LOGFILE
    #echo "" >> $CAPIMA_LOGFILE
    echo -ne "${YELLOW}PHP version of webapp switched to $PHP_VERSION"
    echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
    echo ""
  fi
}

function DeleteWebApp {
  # Define the app name
  local $appname;
  while [[ $appname =~ [^-a-z0-9] ]] || [[ $appname == '' ]]
  do
    read -r -p "${BLUE}Please enter the webapp name you would like to delete:${NORMAL} " appname
    if [[ -z "$appname" ]]; then
      echo -ne "${RED}No app name entered.${NORMAL}"
      echo ""
    fi
  done

  echo -ne "${YELLOW}Please wait, we are removing your web application...${NORMAL}"
  rm -rf $MNTWEB/$appname 2>&1
  rm -rf $WEBAPP_DIR/$appname 2>&1
  rm -rf $NGINX_CONFDIR/$appname.conf 2>&1
  rm -rf $NGINX_CONFDIR/$appname.ssl.conf 2>&1
  rm -rf $NGINX_CONFDIR/$appname.d 2>&1
  rm -rf $NGINX_EXTRA_CONFDIR/$appname*.conf 2>&1
  rm -rf $APACHE_CONFDIR/$appname.conf 2>&1
  rm -rf /etc/php*rc/fpm.d/$appname.conf 2>&1
  rm -rf $PHP_EXTRA_CONFDIR/$appname.conf 2>&1
  rm -rf $CERTDIR/$appname 2>&1
  sed -i "/$appname/d" $CAPIMA_LOGFILE
  echo -ne "${YELLOW}...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""

  RestartServices nginx
  RestartServices apache
  RestartServices php
}

function CreateNewDb {
  # Make request to server
  CheckingRemoteAccessible

  # Define the database name
  local $dbname;
  while [[ $dbname =~ [^-_a-z0-9] ]] || [[ $dbname == '' ]]
  do
    read -r -p "${BLUE}Please enter your database name (lowercase, alphanumeric):${NORMAL} " dbname
    if [[ -z "$dbname" ]]; then
      echo -ne "${RED}No database name entered.${NORMAL}"
      echo ""
    else
      mysql -uroot -p$(GetRootPassword) -e "CREATE DATABASE IF NOT EXISTS ${dbname} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
    fi
  done

  echo -ne "${YELLOW}New database has been created: $dbname"
  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""
}

function UpdateDb {
  echo "${RED}This functionality is being under development... Please try again next year.${NORMAL}"
}

function DeleteDb {
  # Make request to server
  CheckingRemoteAccessible

  # Define the database name
  local $dbname;
  while [[ $dbname =~ [^-_a-z0-9] ]] || [[ $dbname == '' ]]
  do
    read -r -p "${BLUE}Please enter the database name you would like to delete:${NORMAL} " dbname
    if [[ -z "$dbname" ]]; then
      echo -ne "${RED}No database name entered.${NORMAL}"
      echo ""
    fi
  done

  echo -ne "${YELLOW}Please wait, we are removing your database...${NORMAL}"
  mysql -uroot -p$(GetRootPassword) -e "DROP DATABASE ${dbname};"
  echo -ne "${YELLOW}...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""

  exit
}

function ImportDb {
  # Make request to server
  CheckingRemoteAccessible

  # Define the database name
  local $dbname;
  local $dbpath;
  while [[ $dbname =~ [^-_a-z0-9] ]] || [[ $dbname == '' ]]
  do
    read -r -p "${BLUE}Please enter your database name (lowercase, alphanumeric):${NORMAL} " dbname
    if [[ -z "$dbname" ]]; then
      echo -ne "${RED}No database name entered.${NORMAL}"
      echo ""
    fi
  done

  read -r -p "${BLUE}Please enter the local filepath of database:${NORMAL} " dbpath
  if [[ -z "$dbpath" ]]; then
    echo -ne "${RED}No database filepath provided.${NORMAL}"
    echo ""
  else
    pv ${dbpath} | mysql -uroot -p$(GetRootPassword) ${dbname}
  fi

  echo -ne "${YELLOW}${dbpath} has been imported to ${dbname} successfully."
  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""
}

function GetRootPassword {
  cat "$HOMEDIR/.my.cnf" | grep password | sed -e 's/password=//g'
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
  mkdir -p "$MNTWEB/$APPNAME/deploy/"{shared,git-remote-cache}
  mkdir -p "$MNTWEB/$APPNAME/log"
  if [[ "$1" == "magenx" ]]; then
    mkdir -p "$MNTWEB/$APPNAME/log/"{magento,magento_report}
    mkdir -p "$MNTWEB/$APPNAME/"{media,sitemap}
  fi
  chown -Rf "$USER":"$USER" "$WEBAPP_DIR/$APPNAME"
  chown -Rf "$USER":"$USER" "$MNTWEB/$APPNAME"

  # Writing to logfile
  echo -ne "$APPNAME:" >> $CAPIMA_LOGFILE
  echo -ne "$APPDOMAINS:" >> $CAPIMA_LOGFILE
  echo -ne "$PHP_VERSION:" >> $CAPIMA_LOGFILE
  echo -ne "$PUBLICPATH:" >> $CAPIMA_LOGFILE
  echo -ne "$WEBAPP_DIR/$APPNAME:" >> $CAPIMA_LOGFILE
  echo -ne "$MNTWEB/$APPNAME:" >> $CAPIMA_LOGFILE

  # Nginx
  mkdir -p $NGINX_CONFDIR/$APPNAME.d
  wget "$CAPIMAURL/templates/nginx/$1/$1.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g" > $NGINX_CONFDIR/$APPNAME.conf
  if [[ "$SECURED_WEBAPP" == "Y" ]]; then
    if [[ "$SECURED_LIVE" == "Y" ]]; then
      echo -ne "${YELLOW}... Generating Live SSL certificates... "
      if [[ "$OSCODENAME" == 'xenial' ]]; then
        $CERTBOT_AUTO certonly --email "$LE_EMAIL" --agree-tos --webroot -w "$WEBAPP_DIR/$APPNAME/$PUBLICPATH" ${APPDOMAINS_LE[@]} &>/dev/null
      else
        letsencrypt certonly --email "$LE_EMAIL" --agree-tos --webroot -w "$WEBAPP_DIR/$APPNAME/$PUBLICPATH" ${APPDOMAINS_LE[@]} &>/dev/null
      fi
    fi
    if [[ -f "$SECURED_KEYFILE" ]]; then
      echo -ne "${YELLOW}... Working on configurations... "
      wget "$CAPIMAURL/templates/nginx/$1/$1.ssl.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g;s|CERTDIR|$CERTDIR|g;s/APPDOMAINS/$APPDOMAINS/g;s/APPDOMAIN/${APPDOMAINS_CRT[0]}/g" > $NGINX_CONFDIR/$APPNAME.ssl.conf
    fi
  fi

  # Magento 2
  if [[ "$1" == "magenx" ]]; then
    wget "$CAPIMAURL/templates/nginx/$1/$1.d/headers.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g;s/APPDOMAINS/$APPDOMAINS/g;s/MAGEMODE/$MAGE_MODE/g;s|HOMEDIR|$HOMEDIR|g;s|PUBLICPATH|$PUBLICPATH|g" > $NGINX_CONFDIR/$APPNAME.d/headers.conf
    wget "$CAPIMAURL/templates/nginx/$1/$1.d/domain_mapping.conf" --quiet -O - | sed "s/APPDOMAIN/${APPDOMAINS_CRT[0]}/g" > $NGINX_EXTRA_CONFDIR/$APPNAME.location.http.domain_mapping.conf
  else
    wget "$CAPIMAURL/templates/nginx/$1/$1.d/headers.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g" > $NGINX_CONFDIR/$APPNAME.d/headers.conf
  fi
  wget "$CAPIMAURL/templates/nginx/$1/$1.d/main.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g;s/APPDOMAINS/$APPDOMAINS/g;s|HOMEDIR|$HOMEDIR|g;s|PUBLICPATH|$PUBLICPATH|g" > $NGINX_CONFDIR/$APPNAME.d/main.conf
  wget "$CAPIMAURL/templates/nginx/$1/$1.d/proxy.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g" > $NGINX_CONFDIR/$APPNAME.d/proxy.conf
  echo -ne "$NGINX_CONFDIR/$APPNAME.conf:" >> $CAPIMA_LOGFILE
  echo -ne "$NGINX_CONFDIR/$APPNAME.d:" >> $CAPIMA_LOGFILE

  # FastCGI Cache
  if [[ "$USE_CAPICACHE" == "Y" ]]; then
    wget "$CAPIMAURL/templates/nginx/capimacache/headers.d/fcgicache.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g" > $NGINX_EXTRA_CONFDIR/$APPNAME.headers.capima-hub.conf
    wget "$CAPIMAURL/templates/nginx/capimacache/location.d/fcgicache_http.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g" > $NGINX_EXTRA_CONFDIR/$APPNAME.location.http.capima-hub.conf
    wget "$CAPIMAURL/templates/nginx/capimacache/location.d/fcgicache_main_before.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g" > $NGINX_EXTRA_CONFDIR/$APPNAME.location.main-before.capima-hub.conf
    wget "$CAPIMAURL/templates/nginx/capimacache/location.d/fcgicache_proxy.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g" > $NGINX_EXTRA_CONFDIR/$APPNAME.location.proxy.capima-hub.conf
    echo -ne "$NGINX_EXTRA_CONFDIR/$APPNAME.headers.capima-hub.conf:" >> $CAPIMA_LOGFILE
    echo -ne "$NGINX_EXTRA_CONFDIR/$APPNAME.location.http.capima-hub.conf:" >> $CAPIMA_LOGFILE
    echo -ne "$NGINX_EXTRA_CONFDIR/$APPNAME.location.main-before.capima-hub.conf:" >> $CAPIMA_LOGFILE
    echo -ne "$NGINX_EXTRA_CONFDIR/$APPNAME.location.proxy.capima-hub.conf:" >> $CAPIMA_LOGFILE
  fi

  # Apache
  if [[ "$1" == "hybrid" ]]; then
    wget "$CAPIMAURL/templates/apache/$1.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g;s/APPDOMAINS/$APPDOMAINS/g;s|HOMEDIR|$HOMEDIR|g;s|PUBLICPATH|$PUBLICPATH|g" > $APACHE_CONFDIR/$APPNAME.conf
    echo -ne "$APACHE_CONFDIR/$APPNAME.conf:" >> $CAPIMA_LOGFILE
    RestartServices apache
  fi

  # PHP-FPM
  PHP_CONFDIR=$(${PHP_PATHS[$PHP_VERSION]}/bin/php --ini | grep "Scan for additional" | cut -d":" -f2 | cut -d" " -f2)
  wget "$CAPIMAURL/templates/php/fpm.d/appname.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g;s|HOMEDIR|$HOMEDIR|g;s/USER/$USER/g" > "$PHP_FPMDIR/$APPNAME.conf"
  wget "$CAPIMAURL/templates/php/extra/appname.conf" --quiet -O "$PHP_EXTRA_CONFDIR/$APPNAME.conf"
  if [[ "$1" == "magenx" ]]; then
    wget "$CAPIMAURL/templates/php/$1/index-before.conf" --quiet -O "$MNTWEB/$APPNAME/deploy/shared/index-before.php"
    wget "$CAPIMAURL/templates/php/$1/magento-vars.conf" --quiet -O "$MNTWEB/$APPNAME/deploy/shared/magento-vars.php"
    wget "$CAPIMAURL/templates/php/$1/op-exclude.txt" --quiet -O "$MNTWEB/$APPNAME/deploy/shared/op-exclude.txt"
    wget "$CAPIMAURL/templates/php/$1/appname.conf" --quiet -O | sed "s/APPNAME/$APPNAME/g;s|HOMEDIR|$HOMEDIR|g;s/USER/$USER/g;s|PUBLICPATH|$PUBLICPATH|g" > "$PHP_EXTRA_CONFDIR/$APPNAME.conf"
    chown -Rf "$USER":"$USER" "$MNTWEB/$APPNAME/deploy/shared/"
    if [[ ! -f "$WEBAPP_DIR/$APPNAME/$PUBLICPATH/op-exclude.txt" ]]; then
      runuser -l $USER -c "ln -snf $MNTWEB/$APPNAME/deploy/shared/op-exclude.txt $WEBAPP_DIR/$APPNAME/$PUBLICPATH/op-exclude.txt"
    fi
  fi
  echo -ne "$PHP_FPMDIR/$APPNAME.conf:" >> $CAPIMA_LOGFILE
  echo -ne "$PHP_EXTRA_CONFDIR/$APPNAME.conf" >> $CAPIMA_LOGFILE
  echo "" >> $CAPIMA_LOGFILE

  RestartServices nginx
  systemctl restart ${PHP_VERSION}rc-fpm.service

  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""
}

function SwitchPhpCliVersion {
  local user_selected=$2
  local php_version=""
  case "$user_selected" in
    5.5|55|5.6|56)
      if [[ "$OSCODENAME" == 'xenial' ]]; then
        php_version=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$user_selected")
        ln -sf ${PHP_PATHS[$php_version]}/bin/php /usr/bin/php
      else
        use_default=1
      fi
    ;;
    7.0|70|7.1|71)
      if [[ "$OSCODENAME" == 'bionic' ]]; then
        php_version=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$user_selected")
        ln -sf ${PHP_PATHS[$php_version]}/bin/php /usr/bin/php
      else
        use_default=1
      fi
    ;;
    7.2|72|7.3|73)
      if [[ "$OSCODENAME" == 'focal' ]]; then
        php_version=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$user_selected")
        ln -sf ${PHP_PATHS[$php_version]}/bin/php /usr/bin/php
      else
        use_default=1
      fi
    ;;
    7.4|74|8.0|80|8.1|81|8.2|82|8.3|83)
      php_version=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$user_selected")
      ln -sf ${PHP_PATHS[$php_version]}/bin/php /usr/bin/php
    ;;
    *)
      use_default=1
    ;;
  esac

  if [[ ! -z "$use_default" ]]; then
    echo -ne "${YELLOW}This version of PHP does not supported with your server installation."
  else
    echo -ne "${YELLOW}PHP-CLI version set to: $user_selected."
  fi
  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""
}

function EnableServices {
  local user_action=$2
  local user_selected=$3
  local php_version=""
  if [[ $SERVICES == *"$2"* ]]; then
    let "DETECTEDSERVICESCOUNT+=1"
    DETECTEDSERVICESNAME+=" $2"
  fi

  if [[ $DETECTEDSERVICESCOUNT -ne 0 ]]; then
    message="Installer detected $DETECTEDSERVICESCOUNT existing services;$DETECTEDSERVICESNAME. Installation will not proceed."
    echo $message
    exit 1
  fi

  case "$user_action" in
    php)
      case "$user_selected" in
        55|5.5|56|5.6)
          if [[ "$OSCODENAME" == 'xenial' ]]; then
            echo -ne "${YELLOW}Enabling PHP ${user_selected} FPM service"
            php_version=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$user_selected")
            systemctl enable ${ACTUAL_SERVICE[$php_version]}
            echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
            echo ""
          fi
        ;;
        70|7.0|71|7.1)
          if [[ "$OSCODENAME" == 'bionic' ]]; then
            echo -ne "${YELLOW}Enabling PHP ${user_selected} FPM service"
            php_version=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$user_selected")
            systemctl enable ${ACTUAL_SERVICE[$php_version]}
            echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
            echo ""
          fi
        ;;
        72|7.2|73|7.3)
          if [[ "$OSCODENAME" == 'focal' ]]; then
            echo -ne "${YELLOW}Enabling PHP ${user_selected} FPM service"
            php_version=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$user_selected")
            systemctl enable ${ACTUAL_SERVICE[$php_version]}
            echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
            echo ""
          fi
        ;;
        74|7.4|80|8.0|81|8.1|82|8.2|83|8.3)
          echo -ne "${YELLOW}Enabling PHP ${user_selected} FPM service"
          php_version=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$user_selected")
          systemctl enable ${ACTUAL_SERVICE[$php_version]}
          echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
          echo ""
        ;;
        *)
          echo "${RED}Please choose one version of PHP you would like to enable: 5.5, 5.6, 7.0, 7.1, 7.2, 7.3, 8.0, 8.1, 8.2, 8.3.${NORMAL}"
          echo "${RED}You might not able to enable all PHP versions, check compatible map in https://capima.nntoan.com.${NORMAL}"
        ;;
      esac
    ;;
    elasticsearch)
      case "$user_selected" in
        5)
          wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
          echo "deb https://artifacts.elastic.co/packages/5.x/apt stable main" > /etc/apt/sources.list.d/elastic-5.x.list
          echo -ne "${YELLOW}Installing Elastic Search 5.x"
        ;;
        6)
          wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
          echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" > /etc/apt/sources.list.d/elastic-6.x.list
          echo -ne "${YELLOW}Installing Elastic Search 6.x"
        ;;
        7|*)
          wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
          echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" > /etc/apt/sources.list.d/elastic-7.x.list
          echo -ne "${YELLOW}Installing Elastic Search 7.x"
        ;;
      esac
      apt-get update -qq
      apt-get install default-jre elasticsearch -y -qq
      systemctl daemon-reload &>/dev/null
      systemctl enable ${ACTUAL_SERVICE[elasticsearch]} &>/dev/null
      systemctl restart ${ACTUAL_SERVICE[elasticsearch]} &>/dev/null
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
    ;;
    redis)
      echo -ne "${YELLOW}Enabling Redis"
      systemctl enable ${ACTUAL_SERVICE[redis]} &>/dev/null
      systemctl restart ${ACTUAL_SERVICE[redis]} &>/dev/null
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
    ;;
    mailhog)
      echo -ne "${YELLOW}Installing MailHog"
      mkdir -p /opt/Go/src

      source /etc/profile.d/capimapath.sh

      go get github.com/mailhog/MailHog
      go get github.com/mailhog/mhsendmail

      ln -s $GOPATH/bin/MailHog /usr/local/bin/MailHog
      ln -s $GOPATH/bin/mhsendmail /usr/local/bin/mhsendmail

      if [[ "$OSCODENAME" == 'xenial' ]]; then
        echo "sendmail_path = /usr/local/bin/mhsendmail" > /etc/php55rc/conf.d/z-mailhog.ini
        echo "sendmail_path = /usr/local/bin/mhsendmail" > /etc/php56rc/conf.d/z-mailhog.ini
      elif [[ "$OSCODENAME" == 'bionic' ]]; then
        echo "sendmail_path = /usr/local/bin/mhsendmail" > /etc/php70rc/conf.d/z-mailhog.ini
        echo "sendmail_path = /usr/local/bin/mhsendmail" > /etc/php71rc/conf.d/z-mailhog.ini
      elif [[ "$OSCODENAME" == 'focal' ]]; then
        echo "sendmail_path = /usr/local/bin/mhsendmail" > /etc/php72rc/conf.d/z-mailhog.ini
        echo "sendmail_path = /usr/local/bin/mhsendmail" > /etc/php73rc/conf.d/z-mailhog.ini
      fi

      echo "sendmail_path = /usr/local/bin/mhsendmail" > /etc/php74rc/conf.d/z-mailhog.ini
      echo "sendmail_path = /usr/local/bin/mhsendmail" > /etc/php80rc/conf.d/z-mailhog.ini
      echo "sendmail_path = /usr/local/bin/mhsendmail" > /etc/php81rc/conf.d/z-mailhog.ini
      echo "sendmail_path = /usr/local/bin/mhsendmail" > /etc/php82rc/conf.d/z-mailhog.ini
      echo "sendmail_path = /usr/local/bin/mhsendmail" > /etc/php83rc/conf.d/z-mailhog.ini
      RestartServices php

      echo "[Unit]
Description=MailHog Service
After=network.service

[Service]
Type=simple
ExecStart=/usr/local/bin/MailHog -api-bind-addr 127.0.0.1:8025 -ui-bind-addr 127.0.0.1:8025 -smtp-bind-addr 127.0.0.1:1025 > /dev/null 2>&1 &

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/mailhog.service

      systemctl daemon-reload &>/dev/null
      systemctl enable ${ACTUAL_SERVICE[mailhog]} &>/dev/null
      systemctl restart ${ACTUAL_SERVICE[mailhog]} &>/dev/null
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
    ;;
    *)
      echo "${RED}Please choose at least a service you would like to enable: elasticsearch, redis, mailhog, php.${NORMAL}"
    ;;
  esac
}

function DisableServices {
  local user_action=$2
  local user_selected=$3
  local php_version=""

  case "$user_action" in
    php)
      case "$user_selected" in
        55|5.5|56|5.6)
          if [[ "$OSCODENAME" == 'xenial' ]]; then
            echo -ne "${YELLOW}Disabling PHP ${user_selected} FPM service"
            php_version=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$user_selected")
            systemctl disable ${ACTUAL_SERVICE[$php_version]}
            systemctl stop ${ACTUAL_SERVICE[$php_version]}
            echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
            echo ""
          fi
        ;;
        70|7.0|71|7.1)
          if [[ "$OSCODENAME" == 'bionic' ]]; then
            echo -ne "${YELLOW}Enabling PHP ${user_selected} FPM service"
            php_version=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$user_selected")
            systemctl disable ${ACTUAL_SERVICE[$php_version]}
            systemctl stop ${ACTUAL_SERVICE[$php_version]}
            echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
            echo ""
          fi
        ;;
        72|7.2|73|7.3)
          if [[ "$OSCODENAME" == 'focal' ]]; then
            echo -ne "${YELLOW}Enabling PHP ${user_selected} FPM service"
            php_version=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$user_selected")
            systemctl disable ${ACTUAL_SERVICE[$php_version]}
            systemctl stop ${ACTUAL_SERVICE[$php_version]}
            echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
            echo ""
          fi
        ;;
        74|7.4|80|8.0|81|8.1|82|8.2|83|8.3)
          echo -ne "${YELLOW}Enabling PHP ${user_selected} FPM service"
          php_version=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$user_selected")
          systemctl disable ${ACTUAL_SERVICE[$php_version]}
          systemctl stop ${ACTUAL_SERVICE[$php_version]}
          echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
          echo ""
        ;;
        *)
          echo "${RED}Please choose one version of PHP you would like to disable: 5.5, 5.6, 7.0, 7.1, 7.2, 7.3, 7.4, 8.0, 8.1, 8.2, 8.3.${NORMAL}"
          echo "${RED}See list supported of PHP in https://capima.nntoan.com.${NORMAL}"
        ;;
      esac
    ;;
    elasticsearch)
      echo -ne "${YELLOW}Disabling Elastic Search"
      systemctl disable ${ACTUAL_SERVICE[elasticsearch]} &>/dev/null
      systemctl stop ${ACTUAL_SERVICE[elasticsearch]} &>/dev/null
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
    ;;
    redis)
      echo -ne "${YELLOW}Disabling Redis"
      systemctl disable ${ACTUAL_SERVICE[redis]} &>/dev/null
      systemctl stop ${ACTUAL_SERVICE[redis]} &>/dev/null
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
    ;;
    mailhog)
      echo -ne "${YELLOW}Disabling MailHog"
      if [[ -f "/etc/systemd/system/${ACTUAL_SERVICE[$current_choice]}" && -f "/etc/systemd/system/multi-user.target.wants/${ACTUAL_SERVICE[$current_choice]}" ]]; then
        systemctl disable ${ACTUAL_SERVICE[mailhog]}
        systemctl stop ${ACTUAL_SERVICE[mailhog]}
      fi
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
    ;;
    *)
      echo "${RED}Please choose at least a service you would like to disable: elasticsearch, redis, mailhog, php.${NORMAL}"
    ;;
  esac
}

function RestartServices {
  current_choice=$2
  if [[ -z "$2" ]]; then
    current_choice="$1"
  fi

  if [[ -f "/etc/systemd/system/${ACTUAL_SERVICE[$current_choice]}" && -f "/etc/systemd/system/multi-user.target.wants/${ACTUAL_SERVICE[$current_choice]}" ]]; then
    systemctl restart ${ACTUAL_SERVICE[$current_choice]}
  fi

  case "$current_choice" in
    nginx|apache|httpd|elasticsearch|opensearch|redis|mysql|mariadb|mailhog)
      if [[ -f "/etc/systemd/system/${ACTUAL_SERVICE[$current_choice]}" && -f "/etc/systemd/system/multi-user.target.wants/${ACTUAL_SERVICE[$current_choice]}" ]]; then
        systemctl restart ${ACTUAL_SERVICE[$current_choice]}
      fi
    ;;
    php)
      if [[ "$OSCODENAME" == 'xenial' ]]; then
        if [[ -f "/etc/systemd/system/${ACTUAL_SERVICE[php55]}" && -f "/etc/systemd/system/multi-user.target.wants/${ACTUAL_SERVICE[php55]}" ]]; then
          systemctl restart ${ACTUAL_SERVICE[php55]}
        fi
        if [[ -f "/etc/systemd/system/${ACTUAL_SERVICE[php56]}" && -f "/etc/systemd/system/multi-user.target.wants/${ACTUAL_SERVICE[php56]}" ]]; then
          systemctl restart ${ACTUAL_SERVICE[php56]}
        fi
      elif [[ "$OSCODENAME" == 'bionic' ]]; then
        if [[ -f "/etc/systemd/system/${ACTUAL_SERVICE[php70]}" && -f "/etc/systemd/system/multi-user.target.wants/${ACTUAL_SERVICE[php70]}" ]]; then
          systemctl restart ${ACTUAL_SERVICE[php70]}
        fi
        if [[ -f "/etc/systemd/system/${ACTUAL_SERVICE[php71]}" && -f "/etc/systemd/system/multi-user.target.wants/${ACTUAL_SERVICE[php71]}" ]]; then
          systemctl restart ${ACTUAL_SERVICE[php71]}
        fi
      elif [[ "$OSCODENAME" == 'focal' ]]; then
        if [[ -f "/etc/systemd/system/${ACTUAL_SERVICE[php72]}" && -f "/etc/systemd/system/multi-user.target.wants/${ACTUAL_SERVICE[php72]}" ]]; then
          systemctl restart ${ACTUAL_SERVICE[php72]}
        fi
        if [[ -f "/etc/systemd/system/${ACTUAL_SERVICE[php73]}" && -f "/etc/systemd/system/multi-user.target.wants/${ACTUAL_SERVICE[php73]}" ]]; then
          systemctl restart ${ACTUAL_SERVICE[php73]}
        fi
      fi
      if [[ -f "/etc/systemd/system/${ACTUAL_SERVICE[php74]}" && -f "/etc/systemd/system/multi-user.target.wants/${ACTUAL_SERVICE[php74]}" ]]; then
        systemctl restart ${ACTUAL_SERVICE[php74]}
      fi
      if [[ -f "/etc/systemd/system/${ACTUAL_SERVICE[php80]}" && -f "/etc/systemd/system/multi-user.target.wants/${ACTUAL_SERVICE[php80]}" ]]; then
        systemctl restart ${ACTUAL_SERVICE[php80]}
      fi
      if [[ -f "/etc/systemd/system/${ACTUAL_SERVICE[php81]}" && -f "/etc/systemd/system/multi-user.target.wants/${ACTUAL_SERVICE[php81]}" ]]; then
        systemctl restart ${ACTUAL_SERVICE[php81]}
      fi
      if [[ -f "/etc/systemd/system/${ACTUAL_SERVICE[php82]}" && -f "/etc/systemd/system/multi-user.target.wants/${ACTUAL_SERVICE[php82]}" ]]; then
        systemctl restart ${ACTUAL_SERVICE[php82]}
      fi
      if [[ -f "/etc/systemd/system/${ACTUAL_SERVICE[php83]}" && -f "/etc/systemd/system/multi-user.target.wants/${ACTUAL_SERVICE[php83]}" ]]; then
        systemctl restart ${ACTUAL_SERVICE[php83]}
      fi
    ;;
    *|all|--all|-a)
      for service in "${!ACTUAL_SERVICE[@]}"
      do
        if [[ -f "/etc/systemd/system/${ACTUAL_SERVICE[$service]}" && -f "/etc/systemd/system/multi-user.target.wants/${ACTUAL_SERVICE[$service]}" ]]; then
          systemctl restart ${ACTUAL_SERVICE[$service]}
        fi
      done
    ;;
  esac

  if [[ "$?" -eq 0 ]]; then
    if [[ ! -z "$2" ]]; then
      echo -ne "${BLUE}${2} service has been restarted successfully."
    else
      echo -ne "${BLUE}All services has been restarted successfully."
    fi
    echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
    echo ""
  else
    echo -ne "${RED}Something went wrong, please check the logs with journalctl -xe for more information.${NORMAL}"
    echo ""
  fi
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
    echo "${RED}Sorry, we unable to detect your webapp. Please change directory to your webapp then try again.${NORMAL}"
  fi
}

function TailLogs {
  local nginxLogs=$(shopt -s nullglob dotglob; echo $HOMEDIR/logs/nginx/*.log)
  local httpdLogs=$(shopt -s nullglob dotglob; echo $HOMEDIR/logs/apache2/*.log)
  local fpmLogs=$(shopt -s nullglob dotglob; echo $HOMEDIR/logs/fpm/*.log)
  local allLogs=$(shopt -s nullglob dotglob; echo $HOMEDIR/logs/*/*.log)
  case "$2" in
    nginx)
      if [[ ${#nginxLogs} -gt 0 ]]; then
        tail -f ${nginxLogs} -n200
      else
        exit;
      fi
      ;;
    apache)
      if [[ ${#httpdLogs} -gt 0 ]]; then
        tail -f ${httpdLogs} -n200
      else
        exit;
      fi
      ;;
    fpm)
      if [[ ${#fpmLogs} -gt 0 ]]; then
        tail -f ${fpmLogs} -n200
      else
        exit;
      fi
      ;;
    all|*)
      if [[ ${#allLogs} -gt 0 ]]; then
        tail -f ${allLogs} -n200
      else
        exit;
      fi
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

function CheckingRemoteAccessible {
    echo -ne "\n${GREEN}Checking if $CAPIMAURL is accessible...${NORMAL}\n"

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

    # Patching
    PatchAndInstall

    echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL} 🎉🎉🎉"
    echo ""

    exit 0
  fi
}

function PatchAndInstall {
  # Patching
  echo -ne "${GREEN}Patching Capima...${NORMAL}"
  wget "$CAPIMAURL/files/installers/$PATCH_VERSION.sh" --quiet -O - | bash -s "$PATCH_VERSION"
  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""
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
      echo ${GREEN} "db${NORMAL}               Databases management panel (add/import/delete)."
      echo ${GREEN} "use${NORMAL}              Switch between version of PHP-CLI."
      echo ${GREEN} "enable${NORMAL}           Enable optional services (elasticsearch, redis, mailhog, php)."
      echo ${GREEN} "restart${NORMAL}          Restart Capima service(s)."
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
      echo " db${NORMAL}               Databases management panel (add/import/delete)."
      echo " use${NORMAL}              Switch between version of PHP-CLI."
      echo " enable${NORMAL}           Enable optional services (elasticsearch, redis, mailhog, php)."
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
