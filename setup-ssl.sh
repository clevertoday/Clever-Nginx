#!/bin/bash

set -ex

getAcmeArguments() {
  local DOMAINS=(${SUB_DOMAINS//,/ })
  local ARGUMENTS="-d ${DOMAIN}"

  if [ $SKIP_DOMAIN_VALIDATION = true ]; then
    ARGUMENTS=""
  fi

  for i in "${!DOMAINS[@]}"; do
    ARGUMENTS="${ARGUMENTS} -d ${DOMAINS[i]}.${DOMAIN}"
  done

  echo $ARGUMENTS
}

getDomain() {
  if [ $SKIP_DOMAIN_VALIDATION = true ]; then
    local DOMAINS=(${SUB_DOMAINS//,/ })
    echo "${DOMAINS[0]}.${DOMAIN}"
  else
    echo ${DOMAIN}
  fi
}

configureRenewCertificateCronJob() {
  echo "Preparing crontab expression to renew certificate..."
  # Remove existing acme.sh entry in crontab
  crontab -l | grep -v "/root/.acme.sh" | crontab -
  # Add correct PATH in crontab
  crontab -l | { echo 'PATH=/usr/sbin:/usr/bin:/bin'; } | crontab -
  ## Add correct acme.sh entry in crontab
  crontab -l | { cat; echo "45 0 * * * "/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" >> /var/log/acme.log 2>&1"; } | crontab -
  echo "Cron job initialized"
}

startCronService() {
  echo "Starting Cron service..."
  service cron start

  local SERVICE_STATUS=`service cron status`

  if echo $SERVICE_STATUS | grep -q "cron is running"; then
    echo "----------------------"
    echo "Cron service started !"
    echo "----------------------"
  else
    echo "----------------------------"
    echo "FAILED to start cron service"
    echo "----------------------------"
  fi
}

initCron() {
  configureRenewCertificateCronJob
  startCronService
}

backupDefaultCertificates() {
  cp /etc/nginx/tls/nginx.crt /etc/nginx/tls/nginx.crt.bak
  cp /etc/nginx/tls/nginx.key /etc/nginx/tls/nginx.key.bak
}

restoreDefaultCertificates() {
  mv /etc/nginx/tls/nginx.crt.bak /etc/nginx/tls/nginx.crt
  mv /etc/nginx/tls/nginx.key.bak /etc/nginx/tls/nginx.key
}

saveDataToVolume() {
  echo "Saving data on volume"
  cp -rP /etc/nginx/tls /etc/letsencrypt/.
  cp -rP /root/.acme.sh/$MAIN_DOMAIN /etc/letsencrypt/.
  echo "Certificate data saved to /etc/letsencrypt/ !"
}

runLetsEncrypt() {
  if [ ! -z $DOMAIN ]; then

    local MAIN_DOMAIN=$(getDomain)

    echo "Checking for previously generated certificate..."

    if [ -d "/etc/letsencrypt/${MAIN_DOMAIN}" ] && [ -d "/etc/letsencrypt/tls" ]; then
      echo "Copying data from /etc/letsencrypt..."
      cp -rP /etc/letsencrypt/tls /etc/nginx/.
      cp -rP /etc/letsencrypt/$MAIN_DOMAIN /root/.acme.sh/.
    fi

    echo "Generating ssl certificate for $MAIN_DOMAIN..."

    {
      ARGS=$(getAcmeArguments)
      /root/.acme.sh/acme.sh --issue --debug ${ARGS} -w /usr/share/nginx/
      GENERATION_EXIT_CODE=0
    } || {
      GENERATION_EXIT_CODE=$?
    }

    if [ $GENERATION_EXIT_CODE -eq 0 ]; then

      echo "Installing certificate in nginx..."
      backupDefaultCertificates
      /root/.acme.sh/acme.sh --install-cert -d $MAIN_DOMAIN \
        --keypath       /etc/nginx/tls/nginx.key \
        --fullchainpath /etc/nginx/tls/nginx.crt \
        --reloadcmd     "service nginx force-reload"

      if [ -f "/root/.acme.sh/${MAIN_DOMAIN}/fullchain.cer" ]; then
        rm /etc/nginx/tls/nginx.crt.bak
        rm /etc/nginx/tls/nginx.key.bak

        saveDataToVolume
        initCron

        echo "-------------------------------------------"
        echo "Certificate generated and installed, yeah !"
        echo "-------------------------------------------"
      else
        restoreDefaultCertificates
        echo "-------------------------------------"
        echo "Error during certificate installation"
        echo "-------------------------------------"
      fi

    elif [ $GENERATION_EXIT_CODE -eq 2 ]; then
      echo "Certificate already generated"
      initCron
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
