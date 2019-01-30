#!/bin/bash

MYSQL_VERSION=0.5.2
ORGANIZATION_ID=o-xxxxxxxxxx

REGIONS='
us-east-1
'

for region in $REGIONS; do
  aws lambda add-layer-version-permission --region $region --layer-name mysql-libs \
    --statement-id sid1 --action lambda:GetLayerVersion --principal '*' --organization-id $ORGANIZATION_ID \
    --version-number $(aws lambda publish-layer-version --region $region --layer-name mysql-libs --zip-file fileb://mysql-libs.zip \
      --description "MySQL libraries" --query Version --output text) &
done

for job in $(jobs -p); do
  wait $job
done

gem nexus mysql2-${MYSQL_VERSION}-x86_64-linux.gem