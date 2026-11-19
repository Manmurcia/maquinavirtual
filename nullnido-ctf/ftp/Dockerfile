FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends vsftpd gettext-base && \
    rm -rf /var/lib/apt/lists/*

COPY vsftpd.conf.template /etc/vsftpd.conf.template
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 21 21100-21110
ENTRYPOINT ["/entrypoint.sh"]
