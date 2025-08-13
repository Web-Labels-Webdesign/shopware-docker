ARG DOCKWARE_VERSION=6.6.10.4
FROM dockware/dev:${DOCKWARE_VERSION}

LABEL org.opencontainers.image.title="Shopware Docker"
LABEL org.opencontainers.image.description="Enhanced dockware/dev with automatic permission handling for Linux hosts"
LABEL org.opencontainers.image.source="https://github.com/Web-Labels-Webdesign/shopware-docker"
LABEL org.opencontainers.image.authors="Web Labels Webdesign"

COPY --chmod=755 smart-entrypoint.sh /usr/local/bin/smart-entrypoint.sh

ARG HOST_UID=1000
ARG HOST_GID=1000

RUN groupadd -g ${HOST_GID} devuser && \
	useradd -u ${HOST_UID} -g ${HOST_GID} -m devuser && \
	usermod -aG www-data devuser

USER devuser
WORKDIR /var/www/html