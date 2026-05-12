FROM domjudge/judgehost:latest

USER root

# Instala Go desde la fuente oficial para que quede en /usr/local/go/bin/go,
# que es la ruta que DOMjudge espera por defecto.
ARG GO_VERSION=1.22.3

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates wget \
 && wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz \
 && tar -C /usr/local -xzf /tmp/go.tar.gz \
 && rm /tmp/go.tar.gz \
 && rm -rf /var/lib/apt/lists/* \
 && /usr/local/go/bin/go version

ENV PATH="/usr/local/go/bin:${PATH}" \
    GOCACHE=/tmp/.gocache \
    GOPATH=/tmp/.gopath \
    GOMODCACHE=/tmp/.gomodcache \
    GONOSUMDB=* \
    GOFLAGS="" \
    TZ=America/Lima \
    CONTAINER_TIMEZONE=America/Lima
