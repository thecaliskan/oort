ARG OORT_VERSION=8.4
FROM php:${OORT_VERSION}-alpine

# Set Label
LABEL org.opencontainers.image.authors="Emre Çalışkan oort@thecaliskan.com"

# Install PHP extensions
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS postgresql-dev postgresql-libs brotli-dev; \
    pecl install igbinary redis swoole; \
    docker-php-ext-enable igbinary redis swoole; \
    docker-php-ext-install pcntl pdo_mysql pdo_pgsql; \
    apk del --no-network .build-deps

# Install composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Set Production INI
RUN cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

# Add Group User
RUN addgroup -S -g 10000 oort && adduser -D -u 1000 -s /bin/sh oort -G oort

# Set Chown
RUN chown -R oort:oort /var/www

# Set Chmod
RUN chmod -R 755 /var/www

# Set User
USER oort

# Setup working directory
WORKDIR /var/www

# Port Expose
EXPOSE 80

# Add Graceful Stop Signal
STOPSIGNAL SIGTERM

# Add Environment
ENV APP_ENV=production

