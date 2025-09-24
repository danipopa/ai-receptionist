FROM debian:bullseye-slim

# Install FreeSWITCH dependencies
RUN apt-get update && \
    apt-get install -y \
    freeswitch \
    freeswitch-mod-sofia \
    freeswitch-mod-dialplan-xml \
    freeswitch-mod-event-socket \
    freeswitch-mod-voicemail \
    freeswitch-mod-console \
    freeswitch-mod-logfile \
    freeswitch-mod-cdr-csv \
    freeswitch-mod-loopback \
    freeswitch-mod-httapi \
    freeswitch-mod-dptools \
    freeswitch-mod-conference \
    freeswitch-mod-spandsp \
    freeswitch-mod-g723_1 \
    freeswitch-mod-g729 \
    freeswitch-mod-amr \
    freeswitch-mod-speex \
    freeswitch-mod-sndfile \
    freeswitch-mod-native-file \
    freeswitch-mod-local-stream \
    freeswitch-mod-tone-stream && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy FreeSWITCH configuration files
COPY config/freeswitch /usr/local/freeswitch/conf

# Copy entrypoint and healthcheck scripts
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY docker/healthcheck.sh /usr/local/bin/healthcheck.sh

# Set executable permissions for scripts
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Healthcheck command
HEALTHCHECK --interval=30s --timeout=10s --retries=3 CMD /usr/local/bin/healthcheck.sh

# Expose FreeSWITCH ports
EXPOSE 5060/udp 5060/tcp 8021/tcp 8080/tcp

# Start FreeSWITCH
CMD ["freeswitch", "-nonat", "-c"]