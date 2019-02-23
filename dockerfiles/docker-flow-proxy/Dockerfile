# Builder
FROM golang:1.11.5-alpine3.8 as builder
ARG branch=master
RUN apk add git curl
RUN git clone --branch ${branch} https://github.com/docker-flow/docker-flow-proxy.git
RUN cd docker-flow-proxy && GOARCH=arm GOARM=6 go build .
RUN curl -L -o qemu-arm-static.tar.gz https://github.com/multiarch/qemu-user-static/releases/download/v2.11.0/qemu-arm-static.tar.gz
RUN tar xzf qemu-arm-static.tar.gz

FROM arm32v6/haproxy:alpine
COPY --from=builder /go/qemu-arm-static /usr/bin/
ENV CERTS="" \
    CAPTURE_REQUEST_HEADER="" \
    CFG_TEMPLATE_PATH="/cfg/tmpl/haproxy.tmpl" \
    CHECK_RESOLVERS=false \
    CONNECTION_MODE="http-keep-alive" \
    CRT_LIST_PATH="" \
    DEBUG="false" \
    DEFAULT_PORTS="80,443:ssl" \
    DEFAULT_REQ_MODE="http" \
    DO_NOT_RESOLVE_ADDR="false" \
    ENABLE_H2="true" \
    FILTER_PROXY_INSTANCE_NAME="false" \
    HEALTHCHECK="true" \
    HTTPS_ONLY="false" \
    EXTRA_FRONTEND="" \
    LISTENER_ADDRESS="" \
    MODE="default" \
    PROXY_INSTANCE_NAME="docker-flow" \
    RELOAD_ATTEMPTS="5" \
    RELOAD_INTERVAL="5000" REPEAT_RELOAD=false \
    RECONFIGURE_ATTEMPTS="20" \
    SEPARATOR="," \
    SERVICE_NAME="proxy" SERVICE_DOMAIN_ALGO="hdr_beg(host)" \
    STATS_USER="" STATS_USER_ENV="STATS_USER" STATS_PASS="" STATS_PASS_ENV="STATS_PASS" STATS_URI="" STATS_URI_ENV="STATS_URI" STATS_PORT="" \
    TIMEOUT_HTTP_REQUEST="5" TIMEOUT_HTTP_KEEP_ALIVE="15" TIMEOUT_CLIENT="20" TIMEOUT_CONNECT="5" TIMEOUT_QUEUE="30" TIMEOUT_SERVER="20" TIMEOUT_TUNNEL="3600" \
    USERS="" \
    SKIP_ADDRESS_VALIDATION="true" \
    SSL_BIND_OPTIONS="no-sslv3" SSL_BIND_CIPHERS="ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:RSA+AESGCM:RSA+AES:!aNULL:!MD5:!DSS"

COPY --from=builder /go/docker-flow-proxy/scripts/check.sh /usr/local/bin/check.sh
RUN chmod +x /usr/local/bin/check.sh

COPY --from=builder /go/docker-flow-proxy/errorfiles /errorfiles
COPY --from=builder /go/docker-flow-proxy/haproxy.cfg /cfg/haproxy.cfg
RUN mkdir -p /cfg/tmpl /templates /certs /logs
COPY --from=builder /go/docker-flow-proxy/haproxy.tmpl /cfg/tmpl/haproxy.tmpl

COPY --from=builder /go/docker-flow-proxy/docker-flow-proxy /usr/local/bin/docker-flow-proxy
RUN chmod +x /usr/local/bin/docker-flow-proxy

HEALTHCHECK --interval=5s --start-period=3s --timeout=5s CMD check.sh

EXPOSE 80
EXPOSE 443
EXPOSE 8080

CMD ["docker-flow-proxy", "server"]
