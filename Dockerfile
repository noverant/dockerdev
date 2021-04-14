FROM golang:1.15
ENV GO111MODULE="on"
WORKDIR /go/src/app

COPY monitor.go go.mod .

RUN sh -c 'go get -d -v && go build monitor.go'

FROM ubuntu:latest

RUN apt-get update \
 && apt-get install -y -q --no-install-recommends \
    dnsmasq \
 && apt-get clean \
 && rm -r /var/lib/apt/lists/*

# override nginx-proxy templating
COPY --from=0 /go/src/app/monitor /app/
COPY Procfile /app/

# COPY htdocs /var/www/default/htdocs/

ENV DOMAIN_TLD dev
ENV DNS_IP 127.0.0.1
ENV HOSTMACHINE_IP 127.0.0.1
