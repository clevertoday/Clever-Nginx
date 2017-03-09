FROM          nginx:1.11

RUN           apt-get update && apt-get install -y wget cron
RUN           wget -O -  https://get.acme.sh | sh


RUN           mkdir /etc/nginx/tls
COPY          tls                   /etc/nginx/tls
COPY          html                  /usr/share/nginx
COPY          nginx.conf.template   /etc/nginx/nginx.conf.template
COPY          setup-ssl.sh          /setup-ssl.sh
RUN           chmod u+x /setup-ssl.sh

ENTRYPOINT    ["/setup-ssl.sh"]