#!/bin/sh

export MYSQL2_VERSION=0.5.2

docker build --build-arg MYSQL2_VERSION -t mysql2-builder .
docker create -ti --name tmp-builder mysql2-builder bash
docker cp tmp-builder:/tmp/mysql2-${MYSQL2_VERSION}-x86_64-linux.gem .
docker cp tmp-builder:/tmp/mysql-libs.zip .
docker rm -fv tmp-builder
