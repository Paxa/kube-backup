FROM lachlanevenson/k8s-kubectl

LABEL maintainer="Pavel Evstigneev <pavel.evst@gmail.com>"

RUN apk upgrade --update-cache --available && \
    apk add --no-cache curl openssl openssh git bash ruby ruby-json ruby-dev build-base && \
    update-ca-certificates

# https://git.wiki.kernel.org/index.php/GitHosting
RUN mkdir -p ~/.ssh && \
    ssh-keyscan -t rsa,dsa github.com gitlab.com bitbucket.org codebasehq.com >> /root/.ssh/known_hosts

RUN gem install bundler --no-doc

RUN mkdir -p /opt/app
WORKDIR /opt/app

ADD . /opt/app

RUN bundle config set --local without 'development test' && \
    bundle install --retry 10 --system && \
    apk del build-base ruby-dev && \
    rm -rf /var/cache/apk/*

ENV PATH=$PATH:/opt/app/bin

ENTRYPOINT ["sh", "-c"]
CMD ["kube_backup backup && kube_backup push"]
