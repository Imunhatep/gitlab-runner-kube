FROM ubuntu:18.04

ENV HELM_VERSION="v3.1.1"
ENV KUBE_LATEST_VERSION="v1.16.6"

## Install base system
RUN apt update; \
    apt install -yqq \
        gnupg \
        apt-transport-https \
        ca-certificates \
        curl \
        wget \
        software-properties-common \
        apt-transport-https \
        make; \
    apt autoremove

RUN useradd -ms /bin/bash gitlab-runner

## gitlab-runner repo
RUN curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | bash; \
    apt update; \
    apt install -yqq gitlab-runner; \
    apt autoremove;

## kubectl & helm
ADD https://storage.googleapis.com/kubernetes-release/release/${KUBE_LATEST_VERSION}/bin/linux/amd64/kubectl /usr/local/bin/
RUN wget -q https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz -O - | tar -xzO linux-amd64/helm > /usr/local/bin/helm && \
    chmod +x /usr/local/bin/helm &&\
    chmod +x /usr/local/bin/kubectl

COPY docker/etc             /etc
COPY docker/home            /home
COPY docker/entrypoint.sh   /entrypoint

## Ensure correct access rights
RUN chown gitlab-runner:gitlab-runner -R /home/gitlab-runner;

CMD ["run", "--user=gitlab-runner", "--working-directory=/home/gitlab-runner"]
ENTRYPOINT ["/entrypoint"]
