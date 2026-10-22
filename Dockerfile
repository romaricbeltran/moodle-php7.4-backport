FROM debian:buster-slim

ENV DEBIAN_FRONTEND=noninteractive

# Debian Buster est archivé : utiliser les dépôts historiques.
RUN printf '%s\n' \
    'deb http://archive.debian.org/debian buster main' \
    'deb http://archive.debian.org/debian buster-updates main' \
    'deb http://archive.debian.org/debian-security buster/updates main' \
    > /etc/apt/sources.list \
    && apt-get -o Acquire::Check-Valid-Until=false update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       ca-certificates \
       autoconf \
       bison \
       re2c \
       pkg-config \
       git \
       curl \
       unzip \
       libxml2-dev \
       libsqlite3-dev \
       libcurl4-openssl-dev \
       libssl-dev \
       libonig-dev \
       zlib1g-dev \
       libreadline-dev \
       libedit-dev \
       libffi-dev \
       libsodium-dev \
       libargon2-0-dev \
       libicu-dev \
       libkrb5-dev \
       libc-client2007e-dev \
       libjpeg62-turbo-dev \
       libpng-dev \
       libfreetype6-dev \
       libwebp-dev \
       libxpm-dev \
       libzip-dev \
       libxslt1-dev \
       libmagickwand-dev \
       libmagickcore-6.q16-6-extra \
       libjpeg62-turbo-dev \
       libpng-dev \
       libfreetype6-dev \
       libwebp-dev \
       libxpm-dev \
       && rm -rf /var/lib/apt/lists/*

# Copier les sources PHP modifiées : ne pas écraser le patch.
COPY php-src/ /usr/src/php/

WORKDIR /usr/src/php

# Régénérer configure à partir des sources modifiées.
RUN ./buildconf --force

# Compiler PHP 7.4.33 avec les extensions intégrées nécessaires.
RUN ./configure \
    --prefix=/usr/local \
    --with-config-file-path=/usr/local/etc/php \
    --with-config-file-scan-dir=/usr/local/etc/php/conf.d \
    --disable-all \
    --enable-cli \
    --enable-session \
    --enable-bcmath \
    --enable-calendar \
    --enable-ctype \
    --enable-exif \
    --enable-fileinfo \
    --enable-filter \
    --enable-fpm \
    --enable-ftp \
    --enable-json \
    --enable-mbstring \
    --enable-pdo \
    --enable-phar \
    --enable-posix \
    --enable-simplexml \
    --enable-tokenizer \
    --enable-xml \
    --enable-xmlreader \
    --enable-xmlwriter \
    --enable-dom \
    --enable-soap \
    --enable-sockets \
    --enable-pcntl \
    --enable-shmop \
    --enable-sysvmsg \
    --enable-sysvsem \
    --enable-sysvshm \
    --enable-intl \
    --enable-opcache \
    --with-openssl \
    --with-curl \
    --with-zlib \
    --with-libxml \
    --with-sqlite3 \
    --with-pdo-sqlite \
    --with-mysqli=mysqlnd \
    --with-pdo-mysql=mysqlnd \
    --with-jpeg \
    --with-webp \
    --with-xpm \
    --with-freetype \
    --with-gettext \
    --with-kerberos \
    --with-imap \
    --with-imap-ssl \
    --with-xsl \
    --with-zip \
    --with-xmlrpc \
    --with-sodium \
    --with-password-argon2 \
    --with-ffi \
    --with-readline \
    --with-iconv \
    --enable-gd \
    --with-jpeg \
    --with-freetype \
    --with-webp \
    --with-xpm \
    && make -j2 \
    && make install \
    && mkdir -p /usr/local/etc/php/conf.d \
    && cp php.ini-production /usr/local/etc/php/php.ini \
    && printf '%s\n' \
       'zend_extension=opcache' \
       'opcache.enable=1' \
       > /usr/local/etc/php/conf.d/10-opcache.ini \
    && rm -rf /tmp/pear

# Installer PECL et Imagick compatible avec PHP 7.4.
# La version 3.7.0 prend en charge PHP 7.4.
RUN apt-get -o Acquire::Check-Valid-Until=false update \
    && apt-get install -y --no-install-recommends \
       php-pear \
       libc6-dev \
    && pecl channel-update pecl.php.net \
    && printf '\n' | pecl install imagick-3.7.0 \
    && echo 'extension=imagick.so' \
       > /usr/local/etc/php/conf.d/20-imagick.ini \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

CMD ["-v"]
ENTRYPOINT ["php"]
