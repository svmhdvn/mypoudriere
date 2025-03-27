#!/bin/sh
set -eu

# TODO setup NFS
# Set permissions on the EMPT hierarchy
# TODO tighten up permissions

install -d -o root -g wheel -m 1755 /empt/groups
install -d -o soju -g soju -m 0755 /empt/sojudb

# Setup ACME for automatic TLS cert renewal
# TODO setup acme with katcheri.org once everything else is done
# TODO replace with production once working
#acme.sh --home /var/db/acme --set-default-ca --server letsencrypt_test
#acme.sh --home /var/db/acme --issue --standalone -d 'empt.${org_domain}'
#acme.sh --install-cert -d example.com \
#  --fullchain-file /etc/ssl/empt.${org_domain}.crt.pem \
#  --key-file       /etc/ssl/empt.${org_domain}.key.pem  \
#  --reloadcmd     'service nginx force-reload'
