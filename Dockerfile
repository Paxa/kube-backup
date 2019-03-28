FROM lachlanevenson/k8s-kubectl

MAINTAINER Pavel Evstigneev <pavel.evst@gmail.com>

RUN apk upgrade --update-cache --available && \
    apk add curl openssl openssh git bash ruby ruby-json && \
    update-ca-certificates && \
    rm -rf /var/cache/apk/*

# https://git.wiki.kernel.org/index.php/GitHosting
RUN mkdir -p ~/.ssh && \
    ssh-keyscan -t rsa,dsa github.com gitlab.com bitbucket.org codebasehq.com >> /root/.ssh/known_hosts

RUN gem install bundler -v 2.0.1 --no-doc

RUN mkdir -p /opt/app
WORKDIR /opt/app

ADD . /opt/app

RUN bundle install --retry 10 --system

ENV PATH $PATH:/opt/app/bin


ENTRYPOINT ["sh", "-c"]
CMD ["kube_backup backup && kube_backup push"]
