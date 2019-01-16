#!/bin/sh

crond -f &
docker-php-entrypoint php-fpm
