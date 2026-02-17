ARG OORT_VERSION=8.5
ARG ALPINE_VERSION=3.22
ARG SWOOLE_VERSION
FROM php:${OORT_VERSION}-alpine${ALPINE_VERSION}

# Set Label
LABEL org.opencontainers.image.authors="Emre Çalışkan oort@thecaliskan.com"

# Install PHP extensions
RUN set -eux; \
    apk update --no-cache; \
    apk upgrade --no-cache; \
    apk add --no-cache --virtual .build-deps $PHPIZE_DEPS postgresql-dev brotli-dev icu-dev libzip-dev; \
    apk add --no-cache libstdc++ postgresql-libs icu-libs libzip;  \
    pecl install igbinary redis swoole${SWOOLE_VERSION:-} \
    docker-php-ext-enable igbinary redis swoole; \
    docker-php-ext-install bcmath intl pcntl pdo_mysql pdo_pgsql zip; \
    apk del --no-network .build-deps; \
    rm -rf /tmp/pear /usr/local/lib/php/test /usr/local/lib/php/doc /usr/local/lib/php/.registry;

# Install composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Set Production INI
RUN cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

# Add User
RUN set -eux; \
    addgroup -S -g 10000 oort;  \
    adduser -D -u 1000 -s /bin/sh oort -G oort; \
    rm -rf /var/www/html; \
    chown -R oort:oort /var/www; \
    chmod -R 755 /var/www;

# Set User
USER oort

# Setup working directory
WORKDIR /var/www

# Port Expose
EXPOSE 80

# Add Graceful Stop Signal
STOPSIGNAL SIGTERM

# Add Environment
ARG OORT_VERSION=8.5
ENV OORT_VERSION=${OORT_VERSION:-8.5}
ENV APP_ENV=production
ENV APP_DEBUG=0

