# Clever Nginx !

Nginx image that is able to create and configure an ssl certificate for the given domain using let's encrypt and acme.sh script (https://github.com/Neilpang/acme.sh)

## How to use

See folder example for a simple mplementation of clever-nginx

Dockerfile example :

```
FROM software-factory.clevertoday.xyz/clever-nginx:lastest
COPY nginx.conf   /etc/nginx/nginx.conf
```

Add a volume to docker-compose to avoid certificate generation on startup
```
volumes:
  - volume-name:/etc/letsencrypt
```

Give the domain and optionnaly sub domains to validate in the docker-compose
sub domains must be comma separated, with no space
SKIP_DOMAIN_VALIDATION is optionnal and MUST be used with SUB_DOMAINS. It is used to avoid the main domain validation.
```
environment:
     - DOMAIN=mydomain.com
     - SKIP_DOMAIN_VALIDATION=true
     - SUB_DOMAINS=www,plop,other
```

nginx.conf example :

```
server {
  listen 443 ssl http2;
  server_name ${DOMAIN};

  location /.well-known {
    alias /usr/share/nginx/.well-known;
  }
}
```

Use the $DOMAIN environment variable everywhere you reference the domain that will be certified by let's encrypt

And do not forget to add a location the the /.well-known folder so let's encrypt can verify the certificate issued on nginx startup


## Cron to renew certificate

A cronjob is configured by default in the container.
It runs every night at 00:45 an try to renew the certificate if it was emmitted more than 60 days ago.
Cron job logs can be found by default in ```/var/log/acme.log```