ARG DOCKWARE_VERSION=6.6.10.4
FROM dockware/dev:${DOCKWARE_VERSION}

LABEL org.opencontainers.image.title="Shopware Docker"
LABEL org.opencontainers.image.description="Enhanced dockware/dev with automatic permission handling for Linux hosts"
LABEL org.opencontainers.image.source="https://github.com/Web-Labels-Webdesign/shopware-docker"
LABEL org.opencontainers.image.authors="Web Labels Webdesign"

COPY --chmod=755 smart-entrypoint.sh /usr/local/bin/smart-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/smart-entrypoint.sh"]
CMD ["supervisord"]