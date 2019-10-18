FROM drupal:8.7.6

# install extra tools
RUN apt-get update \
  && apt-get install -y git \
  && rm -rf /var/lib/apt/lists/*

# install Composer globally
RUN curl -sS https://getcomposer.org/installer | php \
  && mv composer.phar /usr/local/bin/composer


# download varbase
RUN cd /var \
    && rm -rf /var/www \
    && composer create-project vardot/varbase-project:^8.4.10 www --no-dev --no-interaction -vvv \
    && ln -s /var/www/docroot /var/www/html \
    && chown -R www-data:www-data /var/www/docroot

# place composer files in a directory for Kubernetes persistant volumes
# symlink them to the old location
RUN mkdir /var/www/composer \
    && mv /var/www/composer.* /var/www/composer \
    && ln -s /var/www/composer/composer.json /var/www/composer.json \
    && ln -s /var/www/composer/composer.lock /var/www/composer.lock
    
# create the config folder
RUN mkdir /var/www/docroot/config