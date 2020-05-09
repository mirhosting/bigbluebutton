#!/bin/bash

# install docker and docker-compose
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu  $(lsb_release -cs) stable"
apt-get update
apt-get install docker-ce -y
curl -L "https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
mkdir -p /root/greenlight

# start and enable docker
systemctl start docker
systemctl enable docker

# get some secretsand update .env file
cd /root/greenlight
SECRET_KEY_BASE=$(docker run --rm bigbluebutton/greenlight:v2 bundle exec rake secret)
docker run --rm bigbluebutton/greenlight:v2 cat ./sample.env > ~/greenlight/.env

BIGBLUEBUTTON_URL=$(cat /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties | grep -v '#' | sed -n '/^bigbluebutton.web.serverURL/{s/.*=//;p}')/bigbluebutton/
BIGBLUEBUTTON_SECRET=$(cat /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties   | grep -v '#' | grep securitySalt | cut -d= -f2)

sed -i "s|SECRET_KEY_BASE=.*|SECRET_KEY_BASE=$SECRET_KEY_BASE|" /root/greenlight/.env
sed -i "s|.*BIGBLUEBUTTON_ENDPOINT=.*|BIGBLUEBUTTON_ENDPOINT=$BIGBLUEBUTTON_URL|" /root/greenlight/.env
sed -i "s|.*BIGBLUEBUTTON_SECRET=.*|BIGBLUEBUTTON_SECRET=$BIGBLUEBUTTON_SECRET|" /root/greenlight/.env

if [ ! -f /etc/bigbluebutton/nginx/greenlight.nginx ]; then
    docker run --rm bigbluebutton/greenlight:v2 cat ./greenlight.nginx | tee /etc/bigbluebutton/nginx/greenlight.nginx
    cat > /etc/bigbluebutton/nginx/greenlight-redirect.nginx << HERE
location = / {
  return 307 /b;
}
HERE
    systemctl restart nginx
fi

gem install jwt java_properties

docker run --rm bigbluebutton/greenlight:v2 cat ./docker-compose.yml > /root/greenlight/docker-compose.yml

# change the default passwords
PGPASSWORD=$(openssl rand -hex 8)
sed -i "s/POSTGRES_PASSWORD=password/POSTGRES_PASSWORD=$PGPASSWORD/g" /root/greenlight/docker-compose.yml
sed -i "s/DB_PASSWORD=password/DB_PASSWORD=$PGPASSWORD/g" /root/greenlight/.env
sed -i "s/POSTGRES_DB=postgres/POSTGRES_DB=greenlight_production/g" /root/greenlight/.env

# start docker-compose
docker-compose up -d

# update with password
sleep 15
docker exec greenlight-v2 bundle exec rake admin:create
