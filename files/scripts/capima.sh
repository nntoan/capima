#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# FILE: /usr/sbin/capima
# DESCRIPTION: Capima Box Manager - Everything you need to use Capima Box!
# AUTHOR: Toan Nguyen (htts://github.com/nntoan)
# VERSION: 1.3.1
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
MNTWEB="/mnt/web/production"
WEBAPP_DIR="$HOMEDIR/webapps"
CERTDIR="/opt/Capima/certificates"
SECURED_WEBAPP="X"
SECURED_LIVE="X"
CAPIMAURL="https://capima.nntoan.com"
PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
LE_EMAIL=""
CERTBOT_AUTO="/usr/local/bin/certbot-auto"
SECURED_KEYFILE="$CERTDIR/$APPNAME/privkey.pem"
SECURED_CONFFILE="$CERTDIR/$APPNAME/openssl.conf"
SECURED_CRTFILE="$CERTDIR/$APPNAME/fullchain.pem"
SECURED_CSRFILE="$CERTDIR/$APPNAME/$APPNAME.csr"
LATEST_VERSION="$(curl --silent https://capima.nntoan.com/files/scripts/capima.version)"
# Read-only variables
readonly VERSION="1.3.1"
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
  randomName=$(petname --complexity 2 --words 1)
  randomAppName="app-${randomName}"
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
      echo -ne "${YELLOW}Magento 2 NGINX (Pre-configured for every Magento 2 application)"
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
    5.5|55)
      if [[ "$OSCODENAME" == 'xenial' ]]; then
        PHP_VERSION="php55rc"
        PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      else
        echo -ne "${YELLOW}Your OS version doesn't support this PHP version, fallback to default option"
        PHP_VERSION="php74rc"
        PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      fi
      ;;
    5.6|56)
      if [[ "$OSCODENAME" == 'xenial' ]]; then
        PHP_VERSION="php56rc"
        PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      else
        echo -ne "${YELLOW}Your OS version doesn't support this PHP version, fallback to default option."
        PHP_VERSION="php74rc"
        PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      fi
      ;;
    7.0|70)
      if [[ "$OSCODENAME" == 'bionic' ]]; then
        PHP_VERSION="php70rc"
        PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      else
        echo -ne "${YELLOW}Your OS version doesn't support this PHP version, fallback to default option."
        PHP_VERSION="php74rc"
        PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      fi
      ;;
    7.1|71)
      if [[ "$OSCODENAME" == 'bionic' ]]; then
        PHP_VERSION="php71rc"
        PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      else
        echo -ne "${YELLOW}Your OS version doesn't support this PHP version, fallback to default option."
        PHP_VERSION="php74rc"
        PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      fi
      ;;
    7.2|72)
      if [[ "$OSCODENAME" == 'focal' ]]; then
        PHP_VERSION="php72rc"
        PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      else
        echo -ne "${YELLOW}Your OS version doesn't support this PHP version, fallback to default option."
        PHP_VERSION="php74rc"
        PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      fi
      ;;
    7.3|73)
      if [[ "$OSCODENAME" == 'focal' ]]; then
        PHP_VERSION="php73rc"
        PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      else
        echo -ne "${YELLOW}Your OS version doesn't support this PHP version, fallback to default option."
        PHP_VERSION="php74rc"
        PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      fi
      ;;
    7.4|74)
      PHP_VERSION="php74rc"
      PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      ;;
    8.0|80)
      PHP_VERSION="php80rc"
      PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      ;;
    8.1|81)
      PHP_VERSION="php81rc"
      PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
      ;;
    8.2|82)
      PHP_VERSION="php82rc"
      PHP_CONFDIR="/etc/$PHP_VERSION/fpm.d"
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
  echo "${YELLOW}This functionality is being under development... Please try again next year.${NORMAL}"
}

function DeleteWebApp {
  # Define the app name
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

  systemctl restart nginx-rc.service
  systemctl restart apache2-rc.service
  if [[ "$OSCODENAME" == 'xenial' ]]; then
    systemctl restart php55rc-fpm.service
    systemctl restart php56rc-fpm.service
  elif [[ "$OSCODENAME" == 'bionic' ]]; then
    systemctl restart php70rc-fpm.service
    systemctl restart php71rc-fpm.service
  elif [[ "$OSCODENAME" == 'focal' ]]; then
    systemctl restart php72rc-fpm.service
    systemctl restart php73rc-fpm.service
  fi
  systemctl restart php74rc-fpm.service
  systemctl restart php80rc-fpm.service
  systemctl restart php81rc-fpm.service
  systemctl restart php82rc-fpm.service

  echo -ne "${YELLOW}...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""

  exit
}

function CreateNewDb {
  # Make request to server
  CheckingRemoteAccessible

  # Define the database name
  while [[ $DBNAME =~ [^-_a-z0-9] ]] || [[ $DBNAME == '' ]]
  do
    read -r -p "${BLUE}Please enter your database name (lowercase, alphanumeric):${NORMAL} " DBNAME
    if [[ -z "$DBNAME" ]]; then
      echo -ne "${RED}No database name entered.${NORMAL}"
      echo ""
    else
      mysql -uroot -p$(GetRootPassword) -e "CREATE DATABASE IF NOT EXISTS ${DBNAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
    fi
  done

  echo -ne "${YELLOW}New database has been created: $DBNAME"
  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""
}

function UpdateDb {
  echo "${RED}This functionality is being under development... Please try again next year.${NORMAL}"
}

function DeleteDb {
  # Define the database name
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
  while [[ $DBNAME =~ [^-_a-z0-9] ]] || [[ $DBNAME == '' ]]
  do
    read -r -p "${BLUE}Please enter your database name (lowercase, alphanumeric):${NORMAL} " DBNAME
    if [[ -z "$DBNAME" ]]; then
      echo -ne "${RED}No database name entered.${NORMAL}"
      echo ""
    fi
  done

  read -r -p "${BLUE}Please enter the local filepath of database:${NORMAL} " DBPATH
  if [[ -z "$DBPATH" ]]; then
    echo -ne "${RED}No database filepath provided.${NORMAL}"
    echo ""
  else
    pv ${DBPATH} | mysql -uroot -p$(GetRootPassword) ${DBNAME}
  fi

  echo -ne "${YELLOW}$DBNAME has been imported successfully."
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

  # Apache
  if [[ "$1" == "hybrid" ]]; then
    wget "$CAPIMAURL/templates/apache/$1.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g;s/APPDOMAINS/$APPDOMAINS/g;s|HOMEDIR|$HOMEDIR|g;s|PUBLICPATH|$PUBLICPATH|g" > $APACHE_CONFDIR/$APPNAME.conf
    echo -ne "$APACHE_CONFDIR/$APPNAME.conf:" >> $CAPIMA_LOGFILE
  fi

  # PHP-FPM
  wget "$CAPIMAURL/templates/php/fpm.d/appname.conf" --quiet -O - | sed "s/APPNAME/$APPNAME/g;s|HOMEDIR|$HOMEDIR|g;s/USER/$USER/g" > $PHP_CONFDIR/$APPNAME.conf
  wget "$CAPIMAURL/templates/php/extra/appname.conf" --quiet -O $PHP_EXTRA_CONFDIR/$APPNAME.conf
  if [[ "$1" == "magenx" ]]; then
    wget "$CAPIMAURL/templates/php/index-before.conf" --quiet -O $MNTWEB/$APPNAME/deploy/shared/index-before.php
    wget "$CAPIMAURL/templates/php/magento-vars.conf" --quiet -O $MNTWEB/$APPNAME/deploy/shared/magento-vars.php
    chown -Rf "$USER":"$USER" "$MNTWEB/$APPNAME/deploy/shared/"
  fi
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
      if [[ "$OSCODENAME" == 'xenial' ]]; then
        ln -sf /RunCloud/Packages/php55rc/bin/php /usr/bin/php
      else
        use_default=1
      fi
    ;;
    5.6|56)
      if [[ "$OSCODENAME" == 'xenial' ]]; then
        ln -sf /RunCloud/Packages/php56rc/bin/php /usr/bin/php
      else
        use_default=1
      fi
    ;;
    7.0|70)
      if [[ "$OSCODENAME" == 'bionic' ]]; then
        ln -sf /RunCloud/Packages/php70rc/bin/php /usr/bin/php
      else
        use_default=1
      fi
    ;;
    7.1|71)
      if [[ "$OSCODENAME" == 'bionic' ]]; then
        ln -sf /RunCloud/Packages/php71rc/bin/php /usr/bin/php
      else
        use_default=1
      fi
    ;;
    7.2|72)
      if [[ "$OSCODENAME" == 'focal' ]]; then
        ln -sf /RunCloud/Packages/php72rc/bin/php /usr/bin/php
      else
        use_default=1
      fi
    ;;
    7.3|73)
      if [[ "$OSCODENAME" == 'focal' ]]; then
        ln -sf /RunCloud/Packages/php73rc/bin/php /usr/bin/php
      else
        use_default=1
      fi
    ;;
    7.4|74)
      ln -sf /RunCloud/Packages/php74rc/bin/php /usr/bin/php
    ;;
    8.0|80)
      ln -sf /RunCloud/Packages/php80rc/bin/php /usr/bin/php
    ;;
    8.1|81)
      ln -sf /RunCloud/Packages/php81rc/bin/php /usr/bin/php
    ;;
    8.2|82)
      ln -sf /RunCloud/Packages/php82rc/bin/php /usr/bin/php
    ;;
    *)
      use_default=1
    ;;
  esac

  if [[ ! -z "$use_default" ]]; then
    echo -ne "${YELLOW}This version of PHP does not supported with your server installation."
  else
    echo -ne "${YELLOW}PHP-CLI version set to: $2."
  fi
  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""
}

function EnableServices {
  if [[ $SERVICES == *"$2"* ]]; then
    let "DETECTEDSERVICESCOUNT+=1"
    DETECTEDSERVICESNAME+=" $2"
  fi

  if [[ $DETECTEDSERVICESCOUNT -ne 0 ]]; then
    message="Installer detected $DETECTEDSERVICESCOUNT existing services;$DETECTEDSERVICESNAME. Installation will not proceed."
    echo $message
    exit 1
  fi

  case "$2" in
    php)
      case "$3" in
        55|5.5)
          if [[ "$OSCODENAME" == 'xenial' ]]; then
            echo -ne "${YELLOW}Enabling PHP 5.5 FPM service"
            systemctl enable php55rc-fpm.service
            echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
            echo ""
          fi
        ;;
        56|5.6)
          if [[ "$OSCODENAME" == 'xenial' ]]; then
            echo -ne "${YELLOW}Enabling PHP 5.6 FPM service"
            systemctl enable php56rc-fpm.service
            echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
            echo ""
          fi
        ;;
        70|7.0)
          if [[ "$OSCODENAME" == 'bionic' ]]; then
            echo -ne "${YELLOW}Enabling PHP 7.0 FPM service"
            systemctl enable php70rc-fpm.service
            echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
            echo ""
          fi
        ;;
        71|7.1)
          if [[ "$OSCODENAME" == 'bionic' ]]; then
            echo -ne "${YELLOW}Enabling PHP 7.1 FPM service"
            systemctl enable php71rc-fpm.service
            echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
            echo ""
          fi
        ;;
        72|7.2)
          if [[ "$OSCODENAME" == 'focal' ]]; then
            echo -ne "${YELLOW}Enabling PHP 7.2 FPM service"
            systemctl enable php72rc-fpm.service
            echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
            echo ""
          fi
        ;;
        73|7.3)
          if [[ "$OSCODENAME" == 'focal' ]]; then
            echo -ne "${YELLOW}Enabling PHP 7.3 FPM service"
            systemctl enable php73rc-fpm.service
            echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
            echo ""
          fi
        ;;
        80|8.0)
          echo -ne "${YELLOW}Enabling PHP 8.0 FPM service"
          systemctl enable php80rc-fpm.service
          echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
          echo ""
        ;;
        81|8.1)
          echo -ne "${YELLOW}Enabling PHP 8.1 FPM service"
          systemctl enable php81rc-fpm.service
          echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
          echo ""
        ;;
        82|8.2)
          echo -ne "${YELLOW}Enabling PHP 8.2 FPM service"
          systemctl enable php82rc-fpm.service
          echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
          echo ""
        ;;
        *)
          echo "${RED}Please choose one version of PHP you would like to enable: 5.5, 5.6, 7.0, 7.1, 7.2, 7.3, 8.0, 8.1, 8.2.${NORMAL}"
          echo "${RED}You might not able to enable all PHP versions, check compatible map in https://capima.nntoan.com.${NORMAL}"
        ;;
      esac
    ;;
    elasticsearch)
      case "$3" in
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
      systemctl enable elasticsearch &>/dev/null
      systemctl restart elasticsearch &>/dev/null
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
    ;;
    redis)
      echo -ne "${YELLOW}Enabling Redis"
      systemctl enable redis-server &>/dev/null
      systemctl restart redis-server &>/dev/null
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
        systemctl restart php55rc-fpm.service
        systemctl restart php56rc-fpm.service
      elif [[ "$OSCODENAME" == 'bionic' ]]; then
        echo "sendmail_path = /usr/local/bin/mhsendmail" > /etc/php70rc/conf.d/z-mailhog.ini
        echo "sendmail_path = /usr/local/bin/mhsendmail" > /etc/php71rc/conf.d/z-mailhog.ini
        systemctl restart php70rc-fpm.service
        systemctl restart php71rc-fpm.service
      elif [[ "$OSCODENAME" == 'focal' ]]; then
        echo "sendmail_path = /usr/local/bin/mhsendmail" > /etc/php72rc/conf.d/z-mailhog.ini
        echo "sendmail_path = /usr/local/bin/mhsendmail" > /etc/php73rc/conf.d/z-mailhog.ini
        systemctl restart php72rc-fpm.service
        systemctl restart php73rc-fpm.service
      fi

      echo "sendmail_path = /usr/local/bin/mhsendmail" > /etc/php74rc/conf.d/z-mailhog.ini
      echo "sendmail_path = /usr/local/bin/mhsendmail" > /etc/php80rc/conf.d/z-mailhog.ini
      echo "sendmail_path = /usr/local/bin/mhsendmail" > /etc/php81rc/conf.d/z-mailhog.ini
      echo "sendmail_path = /usr/local/bin/mhsendmail" > /etc/php82rc/conf.d/z-mailhog.ini
      systemctl restart php74rc-fpm.service
      systemctl restart php80rc-fpm.service
      systemctl restart php81rc-fpm.service
      systemctl restart php82rc-fpm.service

      echo "[Unit]
Description=MailHog Service
After=network.service

[Service]
Type=simple
ExecStart=/usr/local/bin/MailHog -api-bind-addr 127.0.0.1:8025 -ui-bind-addr 127.0.0.1:8025 -smtp-bind-addr 127.0.0.1:1025 > /dev/null 2>&1 &

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/mailhog.service

    systemctl daemon-reload &>/dev/null
    systemctl enable mailhog.service &>/dev/null
    systemctl restart mailhog.service &>/dev/null
    echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
    echo ""
    ;;
    *)
      echo "${RED}Please choose at least a service you would like to enable: elasticsearch, redis, mailhog, php.${NORMAL}"
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
      elif [[ "$OSCODENAME" == 'bionic' ]]; then
        systemctl restart php70rc-fpm.service
        systemctl restart php71rc-fpm.service
      elif [[ "$OSCODENAME" == 'focal' ]]; then
        systemctl restart php72rc-fpm.service
        systemctl restart php73rc-fpm.service
      fi
      systemctl restart php74rc-fpm.service
      systemctl restart php80rc-fpm.service
      systemctl restart php81rc-fpm.service
      systemctl restart php82rc-fpm.service
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
      elif [[ "$OSCODENAME" == 'bionic' ]]; then
        systemctl restart php70rc-fpm.service
        systemctl restart php71rc-fpm.service
      elif [[ "$OSCODENAME" == 'focal' ]]; then
        systemctl restart php72rc-fpm.service
        systemctl restart php73rc-fpm.service
      fi
      systemctl restart php74rc-fpm.service
      systemctl restart php80rc-fpm.service
      systemctl restart php81rc-fpm.service
      systemctl restart php82rc-fpm.service
      systemctl restart elasticsearch.service
      systemctl restart redis-server.service
      if [[ -f "/etc/systemd/system/mailhog.service" ]]; then
        systemctl restart mailhog.service
      fi
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
  case "$2" in
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
