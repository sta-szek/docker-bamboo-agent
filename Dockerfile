FROM maven:3.5.3-jdk-8-alpine

LABEL maintainer="Piotr Joński <p.jonski@pojo.pl>"

ENV M3_HOME=${MAVEN_HOME}

RUN apk --update add git openssh && \
    rm -rf /var/lib/apt/lists/* && \
    rm /var/cache/apk/*

CMD bash