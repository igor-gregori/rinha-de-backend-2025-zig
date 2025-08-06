#!/bin/sh
set -e

# Ensure HAProxy runs as root to access Unix sockets
exec haproxy -f /usr/local/etc/haproxy/haproxy.cfg -db