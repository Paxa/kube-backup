FROM lachlanevenson/k8s-kubectl

MAINTAINER Pavel Evstigneev <pavel.evst@gmail.com>

RUN apk upgrade --update-cache --available && \
    apk add curl openssl openssh git bash ruby ruby-bundler ruby-json && \
    update-ca-certificates && \
    rm -rf /var/cache/apk/*

RUN mkdir -p /opt/app
WORKDIR /opt/app

ADD . /opt/app

RUN bundle install --retry 10 --system

ENV PATH $PATH:/opt/app/bin

ENTRYPOINT ["bin/kube_backup"]
