FROM dokku/build-base:0.1.2 AS builder

ENV DEBIAN_FRONTEND=noninteractive

ARG GOLANG_VERSION
ARG WORKDIR=/go/src/github.com/dokku/dokku

WORKDIR ${WORKDIR}

RUN wget -qO /tmp/go${GOLANG_VERSION}.linux.tar.gz "https://storage.googleapis.com/golang/go${GOLANG_VERSION}.linux-$(dpkg --print-architecture).tar.gz" \
  && tar -C /usr/local -xzf /tmp/go${GOLANG_VERSION}.linux.tar.gz \
  && cp /usr/local/go/bin/* /usr/local/bin \
  && mkdir -p ${WORKDIR}/contrib

COPY Makefile ${WORKDIR}/
COPY *.mk ${WORKDIR}/
COPY contrib/dependencies.json ${WORKDIR}/contrib/dependencies.json

RUN make deb-setup sshcommand plugn

COPY . ${WORKDIR}

ENV GOPATH=/go
ENV GOROOT=/usr/local/go

FROM builder as amd64

ARG PLUGIN_MAKE_TARGET
ARG DOKKU_VERSION=master
ARG DOKKU_GIT_REV
ARG IS_RELEASE=false

RUN PLUGIN_MAKE_TARGET=${PLUGIN_MAKE_TARGET} \
  DOKKU_VERSION=${DOKKU_VERSION} \
  DOKKU_GIT_REV=${DOKKU_GIT_REV} \
  IS_RELEASE=${IS_RELEASE} \
  SKIP_GO_CLEAN=true \
  make version copyfiles \
  && make deb-dokku

FROM builder as arm64

COPY --from=amd64 /tmp /tmp
COPY --from=amd64 /usr/local/share/man/man1/dokku.1 /usr/local/share/man/man1/dokku.1-generated

RUN rm -rf /tmp/build-dokku

ARG PLUGIN_MAKE_TARGET
ARG DOKKU_VERSION=master
ARG DOKKU_GIT_REV
ARG IS_RELEASE=false

RUN PLUGIN_MAKE_TARGET=${PLUGIN_MAKE_TARGET} \
  DOKKU_VERSION=${DOKKU_VERSION} \
  DOKKU_GIT_REV=${DOKKU_GIT_REV} \
  IS_RELEASE=${IS_RELEASE} \
  SKIP_GO_CLEAN=true \
  GOARCH=arm64 make version copyfiles \
  && DOKKU_ARCHITECTURE=arm64 GOARCH=arm64 make deb-dokku

RUN ls -lha /tmp/

RUN find / -type f -path "*traefik-vhosts*/functions" -exec cat {} \; 2>/dev/null
RUN ls -R /
