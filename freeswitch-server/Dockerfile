# FreeSWITCH Server using SignalWire packages
ARG DEBIAN_FRONTEND=noninteractive
FROM debian:11-slim

# Set SignalWire token
ARG SIGNALWIRE_TOKEN=pat_tauz2taTBYqemBc9RpTsEuJg

# Install dependencies for adding the repository
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    gnupg2 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Add SignalWire repository with authentication
RUN wget --http-user=signalwire --http-password=${SIGNALWIRE_TOKEN} \
    -O /usr/share/keyrings/signalwire-freeswitch-repo.gpg \
    https://freeswitch.signalwire.com/repo/deb/debian-release/signalwire-freeswitch-repo.gpg

# Create apt auth configuration for SignalWire repository
RUN echo "machine freeswitch.signalwire.com login signalwire password ${SIGNALWIRE_TOKEN}" \
    > /etc/apt/auth.conf.d/signalwire.conf && \
    chmod 600 /etc/apt/auth.conf.d/signalwire.conf

RUN echo "deb [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ bullseye main" \
    > /etc/apt/sources.list.d/freeswitch.list

# Install FreeSWITCH and common modules
RUN apt-get update && apt-get install -y --no-install-recommends \
    freeswitch \
    freeswitch-mod-console \
    freeswitch-mod-logfile \
    freeswitch-mod-enum \
    freeswitch-mod-cdr-csv \
    freeswitch-mod-event-socket \
    freeswitch-mod-sofia \
    freeswitch-mod-loopback \
    freeswitch-mod-commands \
    freeswitch-mod-conference \
    freeswitch-mod-db \
    freeswitch-mod-dptools \
    freeswitch-mod-expr \
    freeswitch-mod-fifo \
    freeswitch-mod-hash \
    freeswitch-mod-esf \
    freeswitch-mod-fsv \
    freeswitch-mod-valet-parking \
    freeswitch-mod-dialplan-xml \
    freeswitch-mod-dialplan-asterisk \
    freeswitch-mod-spandsp \
    freeswitch-mod-g723-1 \
    freeswitch-mod-g729 \
    freeswitch-mod-amr \
    freeswitch-mod-ilbc \
    freeswitch-mod-h26x \
    freeswitch-mod-b64 \
    freeswitch-mod-sndfile \
    freeswitch-mod-native-file \
    freeswitch-mod-local-stream \
    freeswitch-mod-tone-stream \
    freeswitch-mod-lua \
    freeswitch-mod-say-en \
    && rm -rf /var/lib/apt/lists/*

# Copy your custom configuration into the image (if you have any)
# COPY config/ /etc/freeswitch/

# The freeswitch user/group is already created by the package
# Just ensure proper permissions
RUN chown -R freeswitch:freeswitch /etc/freeswitch /var/lib/freeswitch /var/log/freeswitch /usr/share/freeswitch

# Run as root in container (safe and needed for proper access)
# USER freeswitch

# Set the working directory
WORKDIR /var/lib/freeswitch

# Expose necessary ports
EXPOSE 5060/udp 5080/udp 8021/tcp 16384-32768/udp

# Set the command to run FreeSWITCH in the foreground
CMD ["/usr/bin/freeswitch", "-u", "freeswitch", "-g", "freeswitch", "-nonat", "-c"]
