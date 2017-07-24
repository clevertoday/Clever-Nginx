FROM          nginx:1.13
MAINTAINER    Grégoire Weber <gregoire@clevertoday.com>

RUN           apt-get update && apt-get install -y wget cron
RUN           wget -O -  https://get.acme.sh | sh

RUN           mkdir /etc/nginx/tls
RUN           mkdir /etc/letsencrypt
COPY          tls                   /etc/nginx/tls
COPY          setup-ssl.sh          /setup-ssl.sh
RUN           chmod u+x /setup-ssl.sh

VOLUME        ["/etc/letsencrypt"]

ENTRYPOINT    ["/setup-ssl.sh"]