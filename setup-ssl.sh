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
  sleep 10
}

echo "Building nginx config file..."
envsubst < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

( waitNginxUp && runLetsEncrypt ) & nginx -g 'daemon off;'