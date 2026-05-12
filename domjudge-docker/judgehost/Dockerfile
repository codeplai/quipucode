FROM domjudge/judgehost:latest

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
        golang-go \
        ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && go version

ENV GOCACHE=/tmp/.gocache \
    GOPATH=/tmp/.gopath \
    GOFLAGS=-mod=vendor \
    TZ=America/Lima \
    CONTAINER_TIMEZONE=America/Lima
