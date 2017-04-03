#!/bin/bash

set -ex

getAcmeArguments() {
  local DOMAINS=(${SUB_DOMAINS//,/ })
  local ARGUMENTS="-d ${DOMAIN}"

  for i in "${!DOMAINS[@]}"; do
    ARGUMENTS="${ARGUMENTS} -d ${DOMAINS[i]}.${DOMAIN}"
  done

  echo $ARGUMENTS
}

runLetsEncrypt() {

  if [ ! -z $DOMAIN ]; then

    echo "Checking for previously generated certificate..."
    
    if [ -d "/etc/letsencrypt/${DOMAIN}" ] && [ -d "/etc/letsencrypt/tls" ]; then
    
      echo "Copying data from /etc/letsencrypt..."
      cp -rP /etc/letsencrypt/tls /etc/nginx/.
      cp -rP /etc/letsencrypt/$DOMAIN /root/.acme.sh/.
    
    fi

    echo "Generating ssl certificate for $DOMAIN..."

    {
      ARGS=$(getAcmeArguments)
      /root/.acme.sh/acme.sh --issue --debug ${ARGS} -w /usr/share/nginx/
      GENERATION_EXIT_CODE=0
    } || {
      GENERATION_EXIT_CODE=$?
    }

    if [ $GENERATION_EXIT_CODE -eq 0 ]; then

      echo "Installing certificate in nginx..."
      cp /etc/nginx/tls/nginx.crt /etc/nginx/tls/nginx.crt.bak
      cp /etc/nginx/tls/nginx.key /etc/nginx/tls/nginx.key.bak
      /root/.acme.sh/acme.sh --install-cert -d $DOMAIN \
        --keypath       /etc/nginx/tls/nginx.key \
        --fullchainpath /etc/nginx/tls/nginx.crt \
        --reloadcmd     "service nginx force-reload"

      if [ -f "/root/.acme.sh/${DOMAIN}/fullchain.cer" ]; then
        rm /etc/nginx/tls/nginx.crt.bak
        rm /etc/nginx/tls/nginx.key.bak
        
        echo "Saving data on volume"
        cp -rP /etc/nginx/tls /etc/letsencrypt/.
        cp -rP /root/.acme.sh/$DOMAIN /etc/letsencrypt/.
        echo "Certificate data saved to /etc/letsencrypt/ !"
        
        echo "-------------------------------------------"
        echo "Certificate generated and installed, yeah !"
        echo "-------------------------------------------"
      else
        mv /etc/nginx/tls/nginx.crt.bak /etc/nginx/tls/nginx.crt
        mv /etc/nginx/tls/nginx.key.bak /etc/nginx/tls/nginx.key
        echo "-------------------------------------"
        echo "Error during certificate installation"
        echo "-------------------------------------"
      fi  

    elif [ $GENERATION_EXIT_CODE -eq 2 ]; then

      echo "Certificate already generated"
      echo "Check that the crontab to renew certificate is here"
      CRONTAB_LIST=`crontab -l`
      if [ ! grep -q "/root/.acme.sh" $CRONTAB_LIST]; then
        echo "Adding cronjob in crontab to renew certificate..."
        crontab -l | { cat; echo "45 0 * * * "/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" > /dev/null"; } | crontab -
      else
        echo "cron job already there !"
      fi
      
    fi
  else
    echo "Empty env variable DOMAIN, skip the certificate generation"
  fi
}

waitNginxUp() {
  echo "Wait for nginx to be up..."

  NGINX_UP=1
  while [ $NGINX_UP != 0 ]; do
    wget --no-check-certificate localhost &> /dev/null
    NGINX_UP=$?
    sleep 1
  done
}

echo "Building nginx config file..."
envsubst '$DOMAIN' < /etc/nginx/nginx.conf > /etc/nginx/nginx.conf.tmp
mv /etc/nginx/nginx.conf.tmp /etc/nginx/nginx.conf
rm -rf /etc/nginx/nginx.conf.tmp

( waitNginxUp && runLetsEncrypt ) & nginx -g 'daemon off;'