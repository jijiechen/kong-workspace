FROM docker.io/kong/kuma-dp:2.5.1

WORKDIR /var/dp-debug/dlv
COPY ./dlv /var/dp-debug/dlv/
COPY ./dlv_config.yaml /var/dp-debug/dlv/config.yaml
COPY ./dlv_config.yaml /var/dp-debug/dlv/config.yml
COPY ./kuma-dp /var/dp-debug/kuma-dp
WORKDIR  /home/nonroot
# ENTRYPOINT [ "/var/dp-debug/dlv/dlv" ]
# XDG_CONFIG_HOME=/var/dp-debug/ --listen=:2345 --headless=true --api-version=2 --accept-multiclient --log exec /var/dp-debug/kuma-dp -- run --log-level=info --concurrency=2