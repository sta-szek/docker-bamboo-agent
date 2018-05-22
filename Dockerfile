FROM maven:3.5.3-jdk-8-alpine

LABEL maintainer="Piotr Joński <p.jonski@pojo.pl>"

ENV M3_HOME=${MAVEN_HOME}

RUN apk add --update ca-certificates openssl curl bash git openssh libintl gettext \
    && curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
    && mv kubectl /usr/local/bin \
    && chmod +x /usr/local/bin/kubectl \
    && curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh \
    && chmod 700 get_helm.sh \
    && ./get_helm.sh &> /dev/null \
    && helm init --client-only \
    && helm version --client \
    && apk add --virtual build_deps \
    && cp /usr/bin/envsubst /usr/local/bin/envsubst \
    && rm /var/cache/apk/* \
    && rm -rf /tmp/* \
    && rm -rf /var/lib/apt/lists/* \
    && apk del build_deps

COPY config /root/.kube/config

CMD bash