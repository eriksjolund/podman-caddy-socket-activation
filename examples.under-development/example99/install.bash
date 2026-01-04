#!/bin/bash

set -o errexit
set -o nounset

# This script should be executed as root.

repodir=$1
user=$2

# Alternatively a system account with no shell access could be created:
# useradd --system --shell /usr/sbin/nologin --create-home --add-subids-for-system -d "/home/$user" -- "$user"
useradd -- "$user"

uid=$(id -u -- "$user")

sourcedir="$repodir/examples.under-development/example99"

install --mode 0755 -Z -d -o "$user" -g "$user" "/home/$user/caddy_etc"
install --mode 0644 -Z -D -o "$user" -g "$user" --target-directory "/home/$user/caddy_etc" "$sourcedir/Caddyfile"

install --mode 0755 -Z -d -o "$user" -g "$user" "/home/$user/.config"
install --mode 0755 -Z -d -o "$user" -g "$user" "/home/$user/.config/containers"
install --mode 0755 -Z -d -o "$user" -g "$user" "/home/$user/.config/containers/systemd"
install --mode 0644 -Z -D -o "$user" -g "$user" --target-directory "/home/$user/.config/containers/systemd" "$sourcedir/whoami.container"
install --mode 0644 -Z -D -o "$user" -g "$user" --target-directory "/home/$user/.config/containers/systemd" "$sourcedir/example99-net.network"
install --mode 0644 -Z -D -o root -g root --target-directory /etc/systemd/system/ "$sourcedir/example99.socket"

# envsubst is used for substituting placeholders in the text with environment variable values
cat $sourcedir/example99.container.in | envsubst_user=$user envsubst_uid=$uid envsubst > /etc/containers/systemd/example99.container

loginctl enable-linger "$user"

systemctl daemon-reload
systemctl --user -M "$user@" daemon-reload
systemctl --user -M "$user@" start whoami.service
systemctl start example99.socket
