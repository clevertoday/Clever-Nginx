# Clever Nginx !

Nginx image that is able to create and configure an ssl certificate for the given domain using let's encrypt and acme.sh script (https://github.com/Neilpang/acme.sh)

## How to use

Dockerfile example :

```
FROM software-factory.clevertoday.xyz/clever-nginx
COPY nginx.conf.template   /etc/nginx/nginx.conf.template
```

nginx.conf.template example :

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