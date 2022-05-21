#!/bin/sh
set -e 
/usr/bin/supervisord --nodaemon --configuration /etc/supervisord.conf

#exec redis-server --requirepass develop