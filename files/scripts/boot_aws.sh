#!/bin/bash

# Set up variables
touch /etc/profile.d/website.sh
echo "export AWS_DEFAULT_REGION=ap-southeast-2" >> /etc/profile.d/website.sh
echo "export WEBSITE_TYPE=myendeva" >> /etc/profile.d/website.sh
echo "export WEBSITE_SERVER_TYPE=webserver" >> /etc/profile.d/website.sh
echo "export WEBSITE_ENV_TYPE=production" >> /etc/profile.d/website.sh
echo "export DEPLOYMENT_TYPE=both" >> /etc/profile.d/website.sh
echo "export WEBSITE_DOMAIN=www.example.com" >> /etc/profile.d/website.sh
echo "export WEBSITE_BOOTBUCKET=example-m2.bootscripts" >> /etc/profile.d/website.sh
echo "export WEBSITE_BUCKET=example-m2.deployment.production" >> /etc/profile.d/website.sh
echo "export WEBSITE_DESIREDIP='x.x.x.x'" >> /etc/profile.d/website.sh

## instance id
echo "export EC=`curl -s http://169.254.169.254/latest/meta-data/instance-id`" >> /etc/profile.d/website.sh
## project path
echo "export WEBSITE_PATH=/home/www/$WEBSITE_DOMAIN" >> /etc/profile.d/website.sh
source /etc/profile

echo "Env variables are:"
echo /etc/profile.d/website.sh

# Install required tools
echo "Updating yum, installing software:"
yum update -y
yum install docker -y
yum install nfs-utils -y
yum install jq -y
yum install ruby -y

# Improving SSH daemon security
sed -i 's/^HostKey \/etc\/ssh\/ssh_host_ecdsa_key//'  /etc/ssh/sshd_config;
sed -i 's/^HostKey \/etc\/ssh\/ssh_host_ed25519_key//'  /etc/ssh/sshd_config;
sed -i 's/^#Protocol 2/Protocol 2/'  /etc/ssh/sshd_config;
sed -i 's/^#Protocol 2/Protocol 2/'  /etc/ssh/sshd_config;
echo "# Legacy guideliness" >> /etc/ssh/sshd_config;
echo "KexAlgorithms diffie-hellman-group-exchange-sha256" >> /etc/ssh/sshd_config;
echo "Ciphers aes256-ctr,aes192-ctr,aes128-ctr" >> /etc/ssh/sshd_config;
echo "MACs hmac-sha2-256,hmac-sha2-512" >> /etc/ssh/sshd_config;
echo "KeyRegenerationInterval 1800" >> /etc/ssh/sshd_config;
echo "AuthenticationMethods publickey" >> /etc/ssh/sshd_config;
service sshd restart

# Install docker-compose
echo "Installing docker-compose:"
# $(curl --silent "https://api.github.com/repos/docker/compose/releases/latest" | jq -r .tag_name)
DOCKER_COMPOSE_VERSION="1.24.1";
curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m` > /usr/bin/docker-compose;
chmod 755 /usr/bin/docker-compose;
docker-compose --version;

# Init www user
echo "Creating www user:"
useradd -u 5353 www
usermod -a -G docker www

# Start docker
service docker start

## Add global Google DNS
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
## Docker login for root (git > boot.sh)
$(aws ecr get-login --no-include-email --region ap-southeast-2)
## Docker login for www (dockerstopall/dockerstartall scripts)
runuser -l www -c "$(aws ecr get-login --no-include-email --region ap-southeast-2)"

# Install Newrelic
if [ -n "$NEW_RELIC_LICENSE_KEY" ]; then
    echo "Install New Relic server monitor tool"
    rpm -Uvh https://yum.newrelic.com/pub/newrelic/el5/x86_64/newrelic-repo-5-3.noarch.rpm
    yum install -y newrelic-sysmond
    nrsysmond-config --set license_key=$NEW_RELIC_LICENSE_KEY
    usermod -a -G docker newrelic
    ## new relic must started after Docker in order capture stats properly
    service newrelic-sysmond start

    echo "Install New Relic Infrastructure agent"
    echo "license_key: $NEW_RELIC_LICENSE_KEY" > /etc/newrelic-infra.yml;
    curl -o /etc/yum.repos.d/newrelic-infra.repo https://download.newrelic.com/infrastructure_agent/linux/yum/el/6/x86_64/newrelic-infra.repo;
    yum -q makecache -y --disablerepo='*' --enablerepo='newrelic-infra';
    yum install newrelic-infra -y;
fi

# Creating website directory
mkdir -p $WEBSITE_PATH

# Copy env.tgz from s3
#aws s3 cp s3://$WEBSITE_BUCKET/env.tgz $WEBSITE_PATH/env.tgz
#cd $WEBSITE_PATH
#nice tar xzf env.tgz -C .
#rm env.tgz
#if [ -d "env" ]; then
#        echo "env is successfully deployed!"
#else
#        echo "env is not deployed!"
#fi

# Updating mother OS settings
if [ -n "$(grep -i elasticsearch $WEBSITE_PATH/env/$WEBSITE_ENV_TYPE/$WEBSITE_SERVER_TYPE/docker-compose.yml)" ]; then
    echo "Increasing Virtual memory for $WEBSITE_SERVER_TYPE instance...";
    sysctl -w vm.max_map_count=262144
fi

# Install CodeDeploy Agent
#echo "Installing CodeDeploy Agent"
#cd /home/ec2-user
#wget https://aws-codedeploy-$AWS_DEFAULT_REGION.s3.amazonaws.com/latest/install
#chmod +x ./install
#sudo ./install auto
#CodeDeploy=`service codedeploy-agent status`
#echo $CodeDeploy

# sleep for 5s
echo "Sleep for 5s"
sleep 5

# Run project environment build script
#echo "Running env/common/scripts/boot.sh..."
#/bin/bash $WEBSITE_PATH/env/common/scripts/boot.sh;

# Remove deploy script
#echo "Remove deploy script if exist"
#cd $WEBSITE_PATH
#rm -f deploy.sh

echo "";
echo "#####################################";
echo "# BOOT SCRIPT EXECTUION IS FINISHED #";
echo "#####################################";
echo "";