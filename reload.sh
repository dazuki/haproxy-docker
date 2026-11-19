#!/usr/bin/env bash
set -euo pipefail

CONTAINER=haproxy-proxy

podman exec "$CONTAINER" haproxy -c -f /etc/haproxy/conf.d -f /etc/haproxy/services
podman kill -s USR2 "$CONTAINER" >/dev/null
echo "reloaded"
