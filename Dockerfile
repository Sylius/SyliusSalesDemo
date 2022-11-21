# the different stages of this Dockerfile are meant to be built into separate images
# https://docs.docker.com/compose/compose-file/#target

ARG PHP_VERSION=8.0
ARG NODE_VERSION=14
ARG NGINX_VERSION=1.21
ARG ALPINE_VERSION=3.15
ARG COMPOSER_VERSION=2.4
ARG PHP_EXTENSION_INSTALLER_VERSION=latest

FROM composer:${COMPOSER_VERSION} AS composer

FROM mlocati/php-extension-installer:${PHP_EXTENSION_INSTALLER_VERSION} AS php_extension_installer

FROM php:${PHP_VERSION}-fpm-alpine${ALPINE_VERSION} AS sylius_php_prod

# persistent / runtime deps
RUN apk add --no-cache \
        acl \
        file \
        gettext \
        unzip \
    ;

COPY --from=php_extension_installer /usr/bin/install-php-extensions /usr/local/bin/

RUN install-php-extensions apcu curl exif gd iconv intl mbstring pdo_mysql opcache xml zip

COPY --from=composer /usr/bin/composer /usr/bin/composer
COPY docker/php/prod/php.ini        /usr/local/etc/php/php.ini
COPY docker/php/prod/php-cli.ini    /usr/local/etc/php/php-cli.ini
#COPY sylius/config/preload.php      /srv/sylius/config/preload.php

# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1
RUN set -eux; \
    composer clear-cache
ENV PATH="${PATH}:/root/.composer/vendor/bin"

WORKDIR /srv/sylius

# build for production
ENV APP_ENV=prod
ENV SENTRY_DSN=""
ARG SYLIUS_PLUS_TOKEN

COPY sylius/composer.json sylius/composer.lock sylius/symfony.lock ./
RUN set -eux; \
    composer config --global --auth http-basic.sylius.repo.packagist.com token ${SYLIUS_PLUS_TOKEN}; \
    composer install --prefer-dist --no-autoloader --no-interaction --no-scripts --no-progress --no-dev; \
    composer clear-cache

# copy only specifically what we need
COPY sylius/bin bin/
COPY sylius/config config/
COPY sylius/public public/
COPY sylius/src src/
COPY sylius/templates templates/
COPY sylius/translations translations/

RUN set -eux; \
    mkdir -p var/cache var/log; \
    composer dump-autoload --classmap-authoritative; \
    chmod +x bin/console; \
    sync; \
    bin/console sylius:install:assets --no-interaction; \
    bin/console sylius:theme:assets:install public --no-interaction; \
    bin/console ckeditor:install

VOLUME /srv/sylius/public/media

COPY docker/php/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

ENTRYPOINT ["docker-entrypoint"]
CMD ["php-fpm"]

FROM node:${NODE_VERSION}-alpine${ALPINE_VERSION} AS sylius_node

WORKDIR /srv/sylius

RUN set -eux; \
	apk add --no-cache --virtual .build-deps \
		g++ \
		gcc \
		make \
		python2 \
	;

# prevent the reinstallation of vendors at every changes in the source code
COPY sylius/package.json sylius/yarn.lock ./
RUN set -eux; \
    yarn install; \
    yarn cache clean

COPY --from=sylius_php_prod /srv/sylius/vendor/sylius/sylius/src/Sylius/Bundle/UiBundle/Resources/private       vendor/sylius/sylius/src/Sylius/Bundle/UiBundle/Resources/private/
COPY --from=sylius_php_prod /srv/sylius/vendor/sylius/sylius/src/Sylius/Bundle/AdminBundle/Resources/private    vendor/sylius/sylius/src/Sylius/Bundle/AdminBundle/Resources/private/
COPY --from=sylius_php_prod /srv/sylius/vendor/sylius/sylius/src/Sylius/Bundle/ShopBundle/Resources/private     vendor/sylius/sylius/src/Sylius/Bundle/ShopBundle/Resources/private/

COPY --from=sylius_php_prod /srv/sylius/vendor/sylius/sylius/src/Sylius/Bundle/AdminBundle/gulpfile.babel.js    vendor/sylius/sylius/src/Sylius/Bundle/AdminBundle/gulpfile.babel.js
COPY --from=sylius_php_prod /srv/sylius/vendor/sylius/sylius/src/Sylius/Bundle/ShopBundle/gulpfile.babel.js     vendor/sylius/sylius/src/Sylius/Bundle/ShopBundle/gulpfile.babel.js

COPY sylius/gulpfile.babel.js sylius/.babelrc ./
RUN set -eux; \
    GULP_ENV=prod yarn gulp:build

COPY docker/node/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

ENTRYPOINT ["docker-entrypoint"]
CMD ["yarn", "gulp:build"]

FROM nginx:${NGINX_VERSION}-alpine AS sylius_nginx

COPY docker/nginx/conf.d/default.conf /etc/nginx/conf.d/

WORKDIR /srv/sylius

COPY --from=sylius_php_prod /srv/sylius/public public/
COPY --from=sylius_node     /srv/sylius/public public/

FROM sylius_php_prod AS sylius_php_dev

WORKDIR /srv/sylius

ENV APP_ENV=dev

COPY docker/php/dev/php.ini        /usr/local/etc/php/php.ini
COPY docker/php/dev/php-cli.ini    /usr/local/etc/php/php-cli.ini

RUN set -eux; \
    composer install --prefer-dist --no-autoloader --no-interaction --no-scripts --no-progress; \
    composer clear-cache
