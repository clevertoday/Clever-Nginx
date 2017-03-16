#!/bin/bash

set -ex

runLetsEncrypt() {
  echo "Generating ssl certificate for $DOMAIN..."

  /root/.acme.sh/acme.sh --issue --debug -d $DOMAIN -w /usr/share/nginx/

  echo "Installing certificate in nginx..."

  /root/.acme.sh/acme.sh --install-cert -d $DOMAIN \
      --keypath       /etc/nginx/tls/nginx.key \
      --fullchainpath /etc/nginx/tls/nginx.crt \
      --reloadcmd     "service nginx force-reload"

  echo "Done !"
}

waitNginxUp() {
  echo "Wait for nginx to be up..."

  NGINX_UP=1
  while [ $NGINX_UP != 0 ]; do
    wget localhost &> /dev/null
    NGINX_UP=$?
    sleep 1
  done
}

echo "Building nginx config file..."
envsubst '$DOMAIN' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

( waitNginxUp && runLetsEncrypt ) & nginx -g 'daemon off;'