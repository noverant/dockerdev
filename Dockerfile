ARG FOREGO_VERSION=0.16.1

# Use a specific version of golang to build both binaries
FROM golang:1.15 as gobuilder

# Build forego from scratch
# Because this relies on golang workspaces, we need to use go < 1.8. 
FROM gobuilder as forego

# Download the sources for the given version
ARG FOREGO_VERSION
ADD https://github.com/jwilder/forego/archive/v${FOREGO_VERSION}.tar.gz sources.tar.gz

# Move the sources into the right directory
RUN tar -xzf sources.tar.gz && \
   mkdir -p /go/src/github.com/ddollar/ && \
   mv forego-* /go/src/github.com/ddollar/forego

# Install the dependencies and make the forego executable
WORKDIR /go/src/github.com/ddollar/forego/
RUN go get -v ./... && \
   CGO_ENABLED=0 GOOS=linux go build -o forego .


FROM gobuilder as monitor
ENV GO111MODULE="on"
WORKDIR /go/src/app

COPY monitor.go go.mod .

RUN sh -c 'go get -d -v && go build monitor.go'


FROM ubuntu:latest
WORKDIR /app

RUN apt-get update \
 && apt-get install -y -q --no-install-recommends \
    dnsmasq \
 && apt-get clean \
 && rm -r /var/lib/apt/lists/*

COPY Procfile docker-entrypoint.sh .

# Install Forego + docker-gen
COPY --from=monitor /go/src/app/monitor /usr/local/bin/monitor
COPY --from=forego /go/src/github.com/ddollar/forego/forego /usr/local/bin/forego

ENV DOMAIN_TLD dev
ENV DOCKER_NETWORK shared
ENV DNS_IP 127.0.0.1
ENV HOSTMACHINE_IP 127.0.0.1

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["forego", "start", "-r"]