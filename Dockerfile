FROM alpine:3.9 as builder

LABEL maintainer="metowolf <i@i-meto.com>"

ENV PHP_VERSION 7.3.1
ENV GPG_KEYS CBAF69F173A0FEA4B537F470D66C9593118BCCB6

RUN apk add --no-cache gnupg1 curl \
  && mkdir -p /usr/src \
  && cd /usr/src \
  && curl -fSL https://secure.php.net/get/php-$PHP_VERSION.tar.xz/from/this/mirror -o php.tar.xz \
  && curl -fSL https://secure.php.net/get/php-$PHP_VERSION.tar.xz.asc/from/this/mirror -o php.tar.xz.asc \
  && export GNUPGHOME="$(mktemp -d)" \
  && found=''; \
  for server in \
    ha.pool.sks-keyservers.net \
    hkp://keyserver.ubuntu.com:80 \
    hkp://p80.pool.sks-keyservers.net:80 \
    pgp.mit.edu \
  ; do \
    echo "Fetching GPG key $GPG_KEYS from $server"; \
    gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$GPG_KEYS" && found=yes && break; \
  done; \
  test -z "$found" && echo >&2 "error: failed to fetch GPG key $GPG_KEYS" && exit 1; \
  gpg --batch --verify php.tar.xz.asc php.tar.xz \
  && rm -rf "$GNUPGHOME" php.tar.xz.asc

COPY docker-php-source /usr/local/bin/
ENV PHP_INI_DIR /usr/local/etc/php

RUN set -xe \
  && apk add --no-cache \
    autoconf \
    dpkg-dev dpkg \
    file \
    g++ \
    gcc \
    libc-dev \
    make \
    pkgconf \
    re2c \
    argon2-dev \
    coreutils \
    curl-dev \
    libedit-dev \
    openssl-dev \
    libsodium-dev \
    libxml2-dev \
    sqlite-dev \
  \
  && export CFLAGS="-fstack-protector-strong -fpic -fpie -O3" \
		CPPFLAGS="-fstack-protector-strong -fpic -fpie -O3" \
		LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie" \
	&& docker-php-source extract \
	&& cd /usr/src/php \
  \
  && mkdir -p $PHP_INI_DIR/conf.d \
  && addgroup -g 82 -S www-data \
  && adduser -u 82 -D -S -G www-data www-data \
  \
  && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	&& ./configure \
  	--build="$gnuArch" \
    --with-config-file-path="$PHP_INI_DIR" \
    --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
    --enable-option-checking=fatal \
    --with-mhash \
    --enable-ftp \
    --enable-mbstring \
    --enable-mysqlnd \
    --with-password-argon2 \
    --with-sodium=shared \
    --with-curl \
    --with-libedit \
    --with-openssl \
    --with-zlib \
    --enable-fpm \
    --with-fpm-user=www-data \
    --with-fpm-group=www-data \
    --disable-cgi \
  && make -j "$(nproc)" \
	&& make install \
	&& { find /usr/local/bin /usr/local/sbin -type f -perm +0111 -exec strip --strip-all '{}' + || true; } \
	&& make clean \
  && cp -v php.ini-* "$PHP_INI_DIR/" \
  && cd / \
	&& docker-php-source delete \
  \
	&& runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)" \
	&& apk add --no-cache $runDeps \
  && pecl update-channels \
	&& rm -rf /tmp/pear ~/.pearrc

COPY docker-php-ext-* docker-php-entrypoint /usr/local/bin/

ENV COMPOSER_VERSION 1.8.3

RUN apk add --no-cache \
    libzip libzip-dev \
    openssl openssl-dev \
    freetype freetype-dev \
    libpng libpng-dev \
    libjpeg-turbo libjpeg-turbo-dev \
    libintl \
    icu icu-dev \
    libxslt libxslt-dev \
    libxml2-dev \
    gettext-dev \
    tidyhtml-dev \
    imagemagick-dev \
    postgresql-dev \
  && docker-php-ext-configure gd \
    --with-freetype-dir=/usr/include/ \
    --with-jpeg-dir=/usr/include/ \
    --with-png-dir=/usr/include/ \
  && docker-php-ext-configure opcache \
    --enable-opcache \
  && docker-php-ext-install \
    bcmath \
    exif \
    gd \
    gettext \
    iconv \
    intl \
    mysqli \
    opcache \
    pcntl \
    pdo_mysql \
    pdo_pgsql \
    pgsql \
    shmop \
    soap \
    sockets \
    sysvsem \
    tidy \
    tokenizer \
    xmlrpc \
    xsl \
    zip \
  && pecl install redis && docker-php-ext-enable redis \
  && pecl install imagick && docker-php-ext-enable imagick \
  && docker-php-ext-enable sodium \
  && curl -L -o /usr/local/bin/composer https://getcomposer.org/download/$COMPOSER_VERSION/composer.phar \
  && chmod a+x /usr/local/bin/composer


FROM alpine:3.9

COPY --from=builder /usr/local/ /usr/local/

RUN set -x \
  && runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/ \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)" \
	&& apk --no-cache add $runDeps \
	&& addgroup -g 48 -S www-data \
	&& adduser -u 990 -D -S -G www-data www-data \
  && cd /usr/local/etc \
	&& if [ -d php-fpm.d ]; then \
		sed 's!=NONE/!=!g' php-fpm.conf.default | tee php-fpm.conf > /dev/null; \
		cp php-fpm.d/www.conf.default php-fpm.d/www.conf; \
	else \
		mkdir php-fpm.d; \
		cp php-fpm.conf.default php-fpm.d/www.conf; \
		{ \
			echo '[global]'; \
			echo 'include=etc/php-fpm.d/*.conf'; \
		} | tee php-fpm.conf; \
	fi \
	&& { \
		echo '[global]'; \
		echo 'error_log = /proc/self/fd/2'; \
		echo; echo '; https://github.com/docker-library/php/pull/725#issuecomment-443540114'; echo 'log_limit = 8192'; \
		echo; \
		echo '[www]'; \
		echo '; if we send this to /proc/self/fd/1, it never appears'; \
		echo 'access.log = /proc/self/fd/2'; \
		echo; \
		echo 'clear_env = no'; \
		echo; \
		echo '; Ensure worker stdout and stderr are sent to the main error log.'; \
		echo 'catch_workers_output = yes'; \
		echo 'decorate_workers_output = no'; \
	} | tee php-fpm.d/docker.conf \
	&& { \
		echo '[global]'; \
		echo 'daemonize = no'; \
		echo; \
		echo '[www]'; \
		echo 'listen = 9000'; \
	} | tee php-fpm.d/zz-docker.conf \
  && { \
      echo 'opcache.memory_consumption=128'; \
      echo 'opcache.interned_strings_buffer=8'; \
      echo 'opcache.max_accelerated_files=4000'; \
      echo 'opcache.revalidate_freq=60'; \
      echo 'opcache.fast_shutdown=1'; \
      echo 'opcache.enable_cli=1'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini \
  && { \
    echo 'memory_limit=256M'; \
    echo 'upload_max_filesize=50M'; \
    echo 'post_max_size=100M'; \
    echo 'max_execution_time=600'; \
    echo 'default_socket_timeout=3600'; \
    echo 'request_terminate_timeout=600'; \
  } > /usr/local/etc/php/conf.d/options.ini

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]
