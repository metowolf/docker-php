#!/bin/sh

set -e

VERSION=`cat Dockerfile | grep 'ARG PHP_VERSION' | awk -F '=' '{print $2}'`

docker login -u="$DOCKER_USERNAME" -p="$DOCKER_PASSWORD"
docker build -t metowolf/php .

docker images

docker push metowolf/php
docker tag metowolf/php metowolf/php:$VERSION
docker push metowolf/php:$VERSION
