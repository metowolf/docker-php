FROM alpine:3.17

LABEL maintainer="metowolf <i@i-meto.com>"

RUN set -ex \
  && apk upgrade \
  && apk add --no-cache \
    ca-certificates \
    composer \
    php81 \
    php81-fpm \
    # module
    php81-bcmath \
    php81-pecl-apcu \
    php81-ctype \
    php81-dom \
    php81-exif \
    php81-fileinfo \
    php81-ftp \
    php81-gd \
    php81-gettext \
    php81-gmp \
    php81-pecl-imagick \
    php81-intl \
    php81-pecl-memcached \
    php81-mysqli \
    php81-mysqlnd \
    php81-pcntl \
    php81-pdo \
    php81-pdo_mysql \
    php81-pdo_pgsql \
    php81-pdo_sqlite \
    php81-pgsql \
    php81-posix \
    php81-pecl-redis \
    php81-session \
    php81-shmop \
    php81-simplexml \
    php81-soap \
    php81-sockets \
    php81-sodium \
    php81-sqlite3 \
    php81-sysvsem \
    php81-tidy \
    php81-tokenizer \
    php81-xml \
    php81-xmlreader \
    php81-xmlwriter \
    php81-xsl \
    php81-opcache \
  && ln -s /usr/sbin/php-fpm81 /usr/bin/php-fpm \
  && ln -s /etc/php81 /etc/php \
  && { \
      echo '[www]'; \
      echo 'listen = 9000'; \
    } > /etc/php/php-fpm.d/zz-docker.conf \
  && { \
      echo 'opcache.memory_consumption=128'; \
      echo 'opcache.interned_strings_buffer=8'; \
      echo 'opcache.max_accelerated_files=4000'; \
      echo 'opcache.revalidate_freq=60'; \
      echo 'opcache.fast_shutdown=1'; \
      echo 'opcache.enable_cli=1'; \
    } > /etc/php/conf.d/99_opcache.ini \
  && { \
      echo 'memory_limit=256M'; \
      echo 'upload_max_filesize=50M'; \
      echo 'post_max_size=100M'; \
      echo 'max_execution_time=600'; \
      echo 'default_socket_timeout=3600'; \
      echo 'request_terminate_timeout=600'; \
    } > /etc/php/conf.d/options.ini \
  && rm -rf /var/cache/apk/*

WORKDIR /var/www/html

EXPOSE 9000
CMD ["php-fpm", "-F"]
