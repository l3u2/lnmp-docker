#!/bin/sh
set -e 
/usr/bin/supervisord --nodaemon --configuration /etc/supervisor/conf.d/supervisord.conf

#exec redis-server --requirepass develop