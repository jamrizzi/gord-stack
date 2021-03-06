#!/bin/bash

# settings
EMAIL=email@example.com
RANCHER_MYSQL_DATABASE=rancher
MYSQL_PASSWORD=hellodocker
RANCHER_DOMAIN=cloud.yourdomain.com
DUPLICATI_PASSWORD=hellodocker
DUPLICATI_DOMAIN=backup.yourdomain.com

if [ $(whoami) = "root" ]; then # if run as root

# gather information
read -p "Email ("$EMAIL"): " EMAIL_NEW
if [ $EMAIL_NEW ]; then
    EMAIL=$EMAIL_NEW
fi
read -p "Rancher MYSQL Database ("$RANCHER_MYSQL_DATABASE"): " RANCHER_MYSQL_DATABASE_NEW
if [ $RANCHER_MYSQL_DATABASE_NEW ]; then
    RANCHER_MYSQL_DATABASE=$RANCHER_MYSQL_DATABASE_NEW
fi
read -p "MYSQL Password ("$MYSQL_PASSWORD"): " MYSQL_PASSWORD_NEW
if [ $MYSQL_PASSWORD_NEW ]; then
    MYSQL_PASSWORD=$MYSQL_PASSWORD_NEW
fi
read -p "Rancher Domain ("$RANCHER_DOMAIN"): " RANCHER_DOMAIN_NEW
if [ $RANCHER_DOMAIN_NEW ]; then
    RANCHER_DOMAIN=$RANCHER_DOMAIN_NEW
fi
read -p "Duplicati Password ("$DUPLICATI_PASSWORD"): " DUPLICATI_PASSWORD_NEW
if [ $DUPLICATI_PASSWORD_NEW ]; then
    DUPLICATI_PASSWORD=$DUPLICATI_PASSWORD_NEW
fi
read -p "Duplicati Domain ("$DUPLICATI_DOMAIN"): " DUPLICATI_DOMAIN_NEW
if [ $DUPLICATI_DOMAIN_NEW ]; then
    DUPLICATI_DOMAIN=$DUPLICATI_DOMAIN_NEW
fi

# prepare system
apt-get update -y

# install docker
apt-get install -y apt-transport-https ca-certificates
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" | sudo tee /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-cache policy docker-engine
apt-get install -y linux-image-extra-$(uname -r) linux-image-extra-virtual
apt-get update -y
apt-get install -y docker-engine
service docker start
docker run hello-world

# install nginx
docker run -d --name nginx --restart=unless-stopped -p 80:80 -p 443:443 \
       --name nginx-proxy \
       -v /exports/certs:/etc/nginx/certs:ro \
       -v /etc/nginx/vhost.d \
       -v /usr/share/nginx/html \
       -v /var/run/docker.sock:/tmp/docker.sock:ro \
       jwilder/nginx-proxy

docker run -d --restart=unless-stopped \
       -v /exports/certs:/etc/nginx/certs:rw \
       --volumes-from nginx-proxy \
       -v /var/run/docker.sock:/var/run/docker.sock:ro \
       jrcs/letsencrypt-nginx-proxy-companion

# install mariadb
docker run -d --name rancherdb --restart=unless-stopped \
       -v /exports/rancher/mysql:/var/lib/mysql \
       -e MYSQL_DATABASE=$RANCHER_MYSQL_DATABASE \
       -e MYSQL_ROOT_PASSWORD=$MYSQL_PASSWORD \
       mariadb:latest

# install rancher
docker run -d --restart=unless-stopped --link rancherdb:mysql \
       -e CATTLE_DB_CATTLE_MYSQL_HOST=$MYSQL_PORT_3306_TCP_ADDR \
       -e CATTLE_DB_CATTLE_MYSQL_PORT=3306 \
       -e CATTLE_DB_CATTLE_MYSQL_NAME=$RANCHER_MYSQL_DATABASE \
       -e CATTLE_DB_CATTLE_USERNAME=root \
       -e CATTLE_DB_CATTLE_PASSWORD=$MYSQL_PASSWORD \
       -e VIRTUAL_HOST=$RANCHER_DOMAIN \
       -e VIRTUAL_PORT=8080 \
       -e LETSENCRYPT_HOST=$RANCHER_DOMAIN \
       -e LETSENCRYPT_EMAIL=$EMAIL \
       rancher/server:latest

# install duplicati
docker run -d --restart=unless-stopped \
       -v /exports/duplicati/Duplicati:/root/.config/Duplicati \
       -v /exports:/exports \
       -e DUPLICATI_PASS=$DUPLICATI_PASSWORD \
       -e MONO_EXTERNAL_ENCODINGS=UTF-8 \
       -e VIRTUAL_HOST=$DUPLICATI_DOMAIN \
       -e VIRTUAL_PORT=8200 \
       -e LETSENCRYPT_HOST=$DUPLICATI_DOMAIN \
       -e LETSENCRYPT_EMAIL=$EMAIL \
       intersoftlab/duplicati:canary

else # not run as root
echo "this program must be run as root"
echo "exiting"
fi
