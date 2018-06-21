FROM ubuntu:xenial
MAINTAINER Matt Clarke <matt@incendo.ws>

# Modified from: https://github.com/romeOz/docker-apache-php
# Additions from: https://github.com/BirgerK/docker-apache-letsencrypt
# Added support for Let's Encrypt SSL certificates

ENV OS_LOCALE="en_US.UTF-8"
RUN apt-get update && apt-get install -y locales && locale-gen ${OS_LOCALE}
ENV LANG=${OS_LOCALE} \
    LANGUAGE=${OS_LOCALE} \
    LC_ALL=${OS_LOCALE} \
    DEBIAN_FRONTEND=noninteractive

ENV APACHE_CONF_DIR=/etc/apache2 \
    PHP_CONF_DIR=/etc/php/7.2 \
    PHP_DATA_DIR=/var/lib/php

# For Let's Encrypt
ENV LETSENCRYPT_HOME /etc/letsencrypt
ENV DOMAINS ""
ENV WEBMASTER_MAIL ""

# Install Apache2
RUN	\
	BUILD_DEPS='software-properties-common python-software-properties' \
    && dpkg-reconfigure locales \
	&& apt-get install --no-install-recommends -y $BUILD_DEPS \
	&& add-apt-repository -y ppa:ondrej/php \
	&& add-apt-repository -y ppa:ondrej/apache2 \
	&& apt-get update \
    && apt-get install -y curl apache2 libapache2-mod-php7.2 php7.2-cli php7.2-readline php7.2-mbstring php7.2-zip php7.2-intl php7.2-xml php7.2-json php7.2-curl php7.2-gd php7.2-pgsql php7.2-mysql php-pear \
    # Apache settings
    && cp /dev/null ${APACHE_CONF_DIR}/conf-available/other-vhosts-access-log.conf \
    && rm ${APACHE_CONF_DIR}/sites-enabled/000-default.conf ${APACHE_CONF_DIR}/sites-available/000-default.conf \
    && a2enmod rewrite php7.2 ssl \
	# Install composer
	&& curl -sS https://getcomposer.org/installer | php -- --version=1.6.4 --install-dir=/usr/local/bin --filename=composer \
	# Forward request and error logs to docker log collector
	&& ln -sf /dev/stdout /var/log/apache2/access.log \
	&& ln -sf /dev/stderr /var/log/apache2/error.log \
	&& chown www-data:www-data ${PHP_DATA_DIR} -Rf

# Install Let's Encrypt
RUN apt-get -y update && \
    apt-get install -q -y curl apache2 software-properties-common && \
    add-apt-repository ppa:certbot/certbot && \
    apt-get -y update && \
    apt-get install -q -y python-certbot-apache && \
    # Cleaning
    apt-get purge -y --auto-remove $BUILD_DEPS && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Copy configurations
COPY ./configs/proxy_html.conf ${APACHE_CONF_DIR}/mods-available/
COPY ./configs/security.conf ${APACHE_CONF_DIR}/conf-available/
COPY ./configs/apache2.conf ${APACHE_CONF_DIR}/apache2.conf
COPY ./configs/php.ini  ${PHP_CONF_DIR}/apache2/conf.d/custom.ini
COPY ./configs/httpd.conf /usr/local/apache2/httpd.conf
COPY ./configs/options-ssl-apache.conf ${LETSENCRYPT_HOME}/options-ssl-apache.conf

# Copy the entrypoint  
COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod 755 /sbin/entrypoint.sh

# Set volumes etc
WORKDIR /var/www/
EXPOSE 80 443
VOLUME ["/etc/apache2/sites-available", "/var/www" ]

# Start all components
CMD ["/sbin/entrypoint.sh"]