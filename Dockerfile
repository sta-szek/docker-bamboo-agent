FROM alpine:3.12

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

## Get Java
RUN wget --quiet https://cdn.azul.com/public_keys/alpine-signing@azul.com-5d5dc44c.rsa.pub -P /etc/apk/keys/ && \
    echo "https://repos.azul.com/zulu/alpine" >> /etc/apk/repositories && \
    apk --no-cache add zulu11-jdk

ENV JAVA_HOME=/usr/lib/jvm/zulu11-ca

LABEL maintainer="Piotr Joński <p.jonski@pojo.pl>"

## Add curl
RUN apk add --update \
    curl \
    && rm -rf /var/cache/apk/*

## Setup Maven
ARG MAVEN_VERSION=3.6.3
ARG USER_HOME_DIR="/root"
ARG SHA=c35a1803a6e70a126e80b2b3ae33eed961f83ed74d18fcd16909b2d44d7dada3203f1ffe726c17ef8dcca2dcaa9fca676987befeadc9b9f759967a8cb77181c0
ARG BASE_URL=https://apache.osuosl.org/maven/maven-3/${MAVEN_VERSION}/binaries

RUN mkdir -p /usr/share/maven /usr/share/maven/ref \
  && curl -fsSL -o /tmp/apache-maven.tar.gz ${BASE_URL}/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
  && echo "${SHA}  /tmp/apache-maven.tar.gz" | sha512sum -c - \
  && tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1 \
  && rm -f /tmp/apache-maven.tar.gz \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

ENV MAVEN_HOME /usr/share/maven
ENV MAVEN_CONFIG "$USER_HOME_DIR/.m2"

ENV M3_HOME=${MAVEN_HOME}

ENV HELM_VERSION=v2.13.1

## install plantuml & graphviz

ENV PLANTUML_VERSION=1.2020.9
ENV LANG en_US.UTF-8
RUN \
  apk add --no-cache graphviz wget ca-certificates && \
  apk add --no-cache graphviz wget ca-certificates ttf-dejavu fontconfig && \
  wget "http://downloads.sourceforge.net/project/plantuml/${PLANTUML_VERSION}/plantuml.${PLANTUML_VERSION}.jar" -O plantuml.jar 

RUN mkdir /plantuml && cp plantuml.jar /plantuml/plantuml.jar

## install helm, kubectl, jq
RUN apk add --update ca-certificates openssl curl bash git openssh libintl gettext jq \
    && curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
    && mv kubectl /usr/local/bin \
    && chmod +x /usr/local/bin/kubectl \
    && curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh \
    && chmod 700 get_helm.sh \
    && ./get_helm.sh --version $HELM_VERSION \
    && helm init --client-only \
    && helm version --client \
    && apk add --virtual build_deps \
    && cp /usr/bin/envsubst /usr/local/bin/envsubst \
    && rm -rf get_helm.sh

## install grails
ENV GRAILS_VERSION=3.3.9

WORKDIR /usr/lib/jvm
RUN wget https://github.com/grails/grails-core/releases/download/v$GRAILS_VERSION/grails-$GRAILS_VERSION.zip && \
    unzip grails-$GRAILS_VERSION.zip && \
    rm -rf grails-$GRAILS_VERSION.zip && \
    ln -s grails-$GRAILS_VERSION grails

ENV GRAILS_HOME /usr/lib/jvm/grails
ENV PATH $GRAILS_HOME/bin:$PATH

RUN grails --version

## install docker https://github.com/docker-library/docker/blob/master/18.05/Dockerfile

# set up nsswitch.conf for Go's "netgo" implementation (which Docker explicitly uses)
# - https://github.com/docker/docker-ce/blob/v17.09.0-ce/components/engine/hack/make.sh#L149
# - https://github.com/golang/go/blob/go1.9.1/src/net/conf.go#L194-L275
# - docker run --rm debian:stretch grep '^hosts:' /etc/nsswitch.conf
RUN [ ! -e /etc/nsswitch.conf ] && echo 'hosts: files dns' > /etc/nsswitch.conf

ENV DOCKER_CHANNEL edge
ENV DOCKER_VERSION 18.05.0-ce

RUN set -ex; \
	apk add --no-cache --virtual .fetch-deps \
		curl \
		tar \
	; \
	\
# this "case" statement is generated via "update.sh"
	apkArch="$(apk --print-arch)"; \
	case "$apkArch" in \
		x86_64) dockerArch='x86_64' ;; \
		armhf) dockerArch='armel' ;; \
		aarch64) dockerArch='aarch64' ;; \
		ppc64le) dockerArch='ppc64le' ;; \
		s390x) dockerArch='s390x' ;; \
		*) echo >&2 "error: unsupported architecture ($apkArch)"; exit 1 ;;\
	esac; \
	\
	if ! curl -fL -o docker.tgz "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${dockerArch}/docker-${DOCKER_VERSION}.tgz"; then \
		echo >&2 "error: failed to download 'docker-${DOCKER_VERSION}' from '${DOCKER_CHANNEL}' for '${dockerArch}'"; \
		exit 1; \
	fi; \
	\
	tar --extract \
		--file docker.tgz \
		--strip-components 1 \
		--directory /usr/local/bin/ \
	; \
	rm docker.tgz; \
	\
	apk del .fetch-deps; \
	\
	dockerd -v; \
	docker -v

## cleanup
RUN rm /var/cache/apk/* \
    && rm -rf /tmp/* \
	&& rm -f /plantuml.jar \
    && rm -rf /var/lib/apt/lists/* \
    && apk del build_deps

COPY config /root/.kube/config
COPY settings.xml /root/.m2/settings.xml
RUN apk add --update nodejs nodejs-npm

RUN npm install -g redoc-cli

CMD bash
