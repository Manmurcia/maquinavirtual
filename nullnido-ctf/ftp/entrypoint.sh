#!/bin/sh
set -e
: "${PASV_ADDRESS:=127.0.0.1}"
export PASV_ADDRESS
envsubst '${PASV_ADDRESS}' < /etc/vsftpd.conf.template > /etc/vsftpd.conf
exec vsftpd /etc/vsftpd.conf
