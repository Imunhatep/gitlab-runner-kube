# kube-deployer
Helm chart for gitlab-runner with kubectl and helm3, without wiring kubernetes cluster to GitLab as part of auto-devops

### Common usage
One of the usages for this runner is to execute CI/CD pipelines against kubernetes cluster it runs on. 

Example `.gitlab-ci.yaml`:
```yaml

.dev-deploy-kube-abstract:
  stage: deploy
  tags:
  - kube-deployer
  when: manual  
  script:
  - export NAMESPACE="application-deploy-example"
  - cd kubernetes
  # generate manifests
  - kubectl create ns $NAMESPACE || echo "namespace exists"
  # delete previous release
  - kubectl -n $NAMESPACE delete --all
  - sleep 5
  - kubectl -n $NAMESPACE get all
  # install
  - helm install $NAMESPACE -n $NAMESPACE -f ./helm/values.yaml ./charts
  - sleep 5
  - echo "Waiting up to 2 minutes for APP to start.."
  - kubectl -n $NAMESPACE wait --for=condition=ready --timeout=120s pod -l service=application_example || (kubectl -n $NAMESPACE logs -l service=application_example; exit 127)
```


#### RBAC

Access is managed with RBAC, there are 2 confiugrations: 
1. Defined RBAC role in [./charts/kube-deployer/templates/rbac-deployer.yaml](./charts/kube-deployer/templates/rbac-deployer.yaml)
2. List of namespaces for RBAC role [./charts/kube-deployer/values.yaml](./charts/kube-deployer/values.yaml)

### Dockerfile
Docker image used as GitLab deployer (gitlab-runner)

```
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
```

### ToDo
Move RBAC configuration to `values.yaml`
