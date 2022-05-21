FROM lendableuk/php-fpm-alpine:7.4.9-alpine3.11
MAINTAINER liyulu858890@163.com

# Environments
ENV TIMEZONE            Asia/Shanghai
ENV PHP_MEMORY_LIMIT    512M
ENV MAX_UPLOAD          50M
ENV PHP_MAX_FILE_UPLOAD 200
ENV PHP_MAX_POST        100M
ENV COMPOSER_ALLOW_SUPERUSER 1

ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN chmod +x /usr/local/bin/install-php-extensions \
    && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
	&& install-php-extensions \
	bz2 calendar exif gd gettext gmp igbinary imagick memcached mongodb-stable mysqli pdo_pgsql pgsql \
	rdkafka redis shmop ssh2 stomp swoole sysvmsg sysvsem sysvshm xdebug xhprof xsl zip zookeeper \
    && sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
	&& apk update \
	&& apk upgrade \
	&& apk add --no-cache openssh curl-dev openssl-dev pcre-dev pcre2-dev zlib-dev tzdata vim bash git busybox-extras apache2-utils \
 	&& cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
	&& echo "${TIMEZONE}" > /etc/timezone \
	&& sed -i "s/#PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config \
	&& ssh-keygen -t dsa -P "" -f /etc/ssh/ssh_host_dsa_key \
	&& ssh-keygen -t rsa -P "" -f /etc/ssh/ssh_host_rsa_key \ 
	&& ssh-keygen -t ecdsa -P "" -f /etc/ssh/ssh_host_ecdsa_key \
	&& ssh-keygen -t ed25519 -P "" -f /etc/ssh/ssh_host_ed25519_key \
	&& echo "root:123456" | chpasswd \
	&& apk del tzdata \
 	&& rm -rf /var/cache/apk/*

EXPOSE 22 80 443
# Set environments
RUN sed -i "s|;*date.timezone =.*|date.timezone = ${TIMEZONE}|i" "$PHP_INI_DIR/php.ini" && \
    sed -i "s|;*memory_limit =.*|memory_limit = ${PHP_MEMORY_LIMIT}|i" "$PHP_INI_DIR/php.ini" && \
    sed -i "s|;*upload_max_filesize =.*|upload_max_filesize = ${MAX_UPLOAD}|i" "$PHP_INI_DIR/php.ini" && \
    sed -i "s|;*max_file_uploads =.*|max_file_uploads = ${PHP_MAX_FILE_UPLOAD}|i" "$PHP_INI_DIR/php.ini" && \
    sed -i "s|;*post_max_size =.*|post_max_size = ${PHP_MAX_POST}|i" "$PHP_INI_DIR/php.ini" && \
    sed -i "s|;*cgi.fix_pathinfo=.*|cgi.fix_pathinfo= 0|i" "$PHP_INI_DIR/php.ini"

#Install-Composer
RUN curl -sS https://getcomposer.org/installer | \
    php -- --install-dir=/usr/bin/ --filename=composer


#ADD-NGINX
RUN apk add nginx
COPY ./nginx/conf.d/default.conf /etc/nginx/conf.d/
COPY ./nginx/nginx.conf /etc/nginx/
COPY ./nginx/cert/ /etc/nginx/cert/

RUN mkdir -p /usr/share/nginx/html/public/
COPY ./php/index.php /usr/share/nginx/html/public/

VOLUME ["/usr/share/nginx/html","/var/run/"]

#ADD-SUPERVISOR
RUN apk add supervisor \
 && rm -rf /var/cache/apk/*

# Define mountable directories.
VOLUME ["/etc/supervisord.d", "/var/log/"]
# 把当前目录supervisor文件下的所有内容[不包括supervisor文件夹]添加到容器/etc/目录下
COPY ./supervisor/ /etc/

#ADD-CRONTABS
COPY ./crontabs/default /var/spool/cron/crontabs/
RUN cat /var/spool/cron/crontabs/default >> /var/spool/cron/crontabs/root
RUN mkdir -p /var/log/cron \
 && touch /var/log/cron/cron.log

VOLUME /var/log/cron

#添加启动脚本
WORKDIR /usr/share/nginx/html

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod 777 /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
# CMD ["/usr/bin/supervisord", "--nodaemon", "--configuration", "/etc/supervisord.conf"]
# 参考网址
# https://segmentfault.com/a/1190000018415600
# https://blog.csdn.net/shenlichuang/article/details/106626382
# https://segmentfault.com/a/1190000039823931?sort=newest
# docker build --no-cache -t php-fpm-nginx-alpine:20220521 .
# docker images
# docker run -d -p 8086:80 -p 8022:22 --name web php-fpm-nginx-alpine:20220521
# docker exec -it web sh
# curl http://localhsot