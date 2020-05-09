#!/bin/bash -ex

usage() {
    set +x
    cat 1>&2 <<HERE
    
Script to update hostname and regenerate SSL for BigBlueButton installation

Usage: update-ssl.sh -s new.hostname.com -e info@example.com

HERE
}

main() {
  export DEBIAN_FRONTEND=noninteractive
  LETS_ENCRYPT_OPTIONS="--webroot --non-interactive"
  
  while builtin getopts "hs:e:" opt "${@}"; do
  
  case $opt in
      h)
        usage
        exit 0
        ;;

      s)
        HOST=$OPTARG
        ;;
      e)
        EMAIL=$OPTARG
        ;;
      :)
        err "Missing option argument for -$OPTARG"
        exit 1
        ;;

      \?)
        err "Invalid option: -$OPTARG" >&2
        usage
        ;;
    esac
  done
  
  install_ssl
  
}

install_ssl() {
  if ! grep -q $HOST /usr/local/bigbluebutton/core/scripts/bigbluebutton.yml; then
    bbb-conf --setip $HOST
  fi

  if [ ! -f /etc/letsencrypt/live/$HOST/fullchain.pem ]; then
    rm -f /tmp/bigbluebutton.bak
    if ! grep -q $HOST /etc/nginx/sites-available/bigbluebutton; then  # make sure we can do the challenge
      cp /etc/nginx/sites-available/bigbluebutton /tmp/bigbluebutton.bak
      cat <<HERE > /etc/nginx/sites-available/bigbluebutton
server {
  listen 80;
  listen [::]:80;
  server_name $HOST;
  access_log  /var/log/nginx/bigbluebutton.access.log;
  # BigBlueButton landing page.
  location / {
    root   /var/www/bigbluebutton-default;
    index  index.html index.htm;
    expires 1m;
  }
  # Redirect server error pages to the static page /50x.html
  #
  error_page   500 502 503 504  /50x.html;
  location = /50x.html {
    root   /var/www/nginx-default;
  }
}
HERE
      systemctl restart nginx
    fi

    certbot --email $EMAIL --agree-tos --rsa-key-size 4096 -w /var/www/bigbluebutton-default/ \
       -d $HOST --deploy-hook "systemctl restart nginx" $LETS_ENCRYPT_OPTIONS certonly
  fi

  cat <<HERE > /etc/nginx/sites-available/bigbluebutton
server {
  listen 80;
  listen [::]:80;
  server_name $HOST;
  listen 443 ssl;
  listen [::]:443 ssl;
    ssl_certificate /etc/letsencrypt/live/$HOST/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$HOST/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers "ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS:!AES256";
    ssl_prefer_server_ciphers on;
    ssl_dhparam /etc/nginx/ssl/dhp-4096.pem;
  access_log  /var/log/nginx/bigbluebutton.access.log;
   # Handle RTMPT (RTMP Tunneling).  Forwards requests
   # to Red5 on port 5080
  location ~ (/open/|/close/|/idle/|/send/|/fcs/) {
    proxy_pass         http://127.0.0.1:5080;
    proxy_redirect     off;
    proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
    client_max_body_size       10m;
    client_body_buffer_size    128k;
    proxy_connect_timeout      90;
    proxy_send_timeout         90;
    proxy_read_timeout         90;
    proxy_buffering            off;
    keepalive_requests         1000000000;
  }
  # Handle desktop sharing tunneling.  Forwards
  # requests to Red5 on port 5080.
  location /deskshare {
     proxy_pass         http://127.0.0.1:5080;
     proxy_redirect     default;
     proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
     client_max_body_size       10m;
     client_body_buffer_size    128k;
     proxy_connect_timeout      90;
     proxy_send_timeout         90;
     proxy_read_timeout         90;
     proxy_buffer_size          4k;
     proxy_buffers              4 32k;
     proxy_busy_buffers_size    64k;
     proxy_temp_file_write_size 64k;
     include    fastcgi_params;
  }
  # BigBlueButton landing page.
  location / {
    root   /var/www/bigbluebutton-default;
    index  index.html index.htm;
    expires 1m;
  }
  # Include specific rules for record and playback
  include /etc/bigbluebutton/nginx/*.nginx;
  #error_page  404  /404.html;
  # Redirect server error pages to the static page /50x.html
  #
  error_page   500 502 503 504  /50x.html;
  location = /50x.html {
    root   /var/www/nginx-default;
  }
}
HERE


  # Update Greenlight (if installed) to use SSL
  if [ -f ~/greenlight/.env ]; then
    BIGBLUEBUTTON_URL=$HOST/bigbluebutton/
    sed -i "s|.*BIGBLUEBUTTON_ENDPOINT=.*|BIGBLUEBUTTON_ENDPOINT=$BIGBLUEBUTTON_URL|" ~/greenlight/.env
    docker-compose -f ~/greenlight/docker-compose.yml down
    docker-compose -f ~/greenlight/docker-compose.yml up -d
  fi

  # Update HTML5 client (if installed) to use SSL
  if [ -f  /usr/share/meteor/bundle/programs/server/assets/app/config/settings-production.json ]; then
    sed -i "s|\"wsUrl.*|\"wsUrl\": \"wss://$HOST/bbb-webrtc-sfu\",|g" \
      /usr/share/meteor/bundle/programs/server/assets/app/config/settings-production.json
  fi

  systemctl restart nginx
}


main "$@" || exit 1
