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