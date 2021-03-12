FROM navikt/common:0.1 AS navikt-common
# Used to copy /usr/local/openjdk-15 into image for additional JDK
FROM openjdk:15-slim AS openjdk-15
# Default Maven and JDK - can be replaced with eg. maven:3.6.3-openjdk-15-slim when JDK 11 is no longer needed
FROM maven:3.6.3-openjdk-11-slim
LABEL maintainer="Team Melosys"

# Can be set as a Docker build-arg, and should have the most recent minor version for deployment on NAIS
ARG GITHUB_RUNNER_VERSION="2.277.1"
# GITHUB_TOKEN is set either as a Docker build-arg or when authenticating as https://github.com/apps/melosys-runner/
ARG GITHUB_TOKEN=""

ENV GITHUB_OWNER=navikt
ENV GITHUB_REPOSITORY=melosys-api
ENV RUNNER_WORKDIR="_work"
# Additional labels (replace with your own for local testing)
ENV RUNNER_LABELS="local"

# Install required packages
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && apt-get install -y \
        git \
        curl \
        sudo \
        jq \
        locales
RUN apt-get clean && rm -rf /var/lib/apt/lists/*
RUN useradd -m github \
    && usermod -aG sudo github \
    && echo "%sudo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Norwegian locale for Java tests
RUN sed -i -e 's/# nb_NO.UTF-8 UTF-8/nb_NO.UTF-8 UTF-8/' /etc/locale.gen && locale-gen
ENV LC_ALL="nb_NO.UTF-8"
ENV LANG="nb_NO.UTF-8"
ENV TZ="Europe/Oslo"

# Install scripts from https://github.com/navikt/github-apps-support to auth as https://github.com/apps/melosys-runner/
RUN git clone https://github.com/navikt/github-apps-support.git /github-apps-support \
    && ln -s /github-apps-support/bin/generate-installation-token.sh /usr/bin/generate-installation-token \
    && ln -s /github-apps-support/bin/generate-jwt.sh /usr/bin/generate-jwt

USER github
WORKDIR /home/github

RUN curl -Ls https://github.com/actions/runner/releases/download/v${GITHUB_RUNNER_VERSION}/actions-runner-linux-x64-${GITHUB_RUNNER_VERSION}.tar.gz \
    | tar xz && sudo ./bin/installdependencies.sh

# Replace global Maven settings to use internal Nexus (https://repo.adeo.no) with GitHub Package Registry (GPR) proxy
COPY maven-settings.xml /usr/share/maven/conf/settings.xml
COPY --from=openjdk-15 /usr/local/openjdk-15 /usr/local/openjdk-15

# Add entrypoint scripts from repository and https://github.com/navikt/baseimages/tree/master/common
COPY --chown=github:github run-script.sh /run-script.sh
COPY --from=navikt-common /init-scripts /init-scripts
COPY --from=navikt-common /dumb-init /dumb-init
COPY --chown=github:github --from=navikt-common /entrypoint.sh /entrypoint.sh

RUN sudo chmod u+x /entrypoint.sh /run-script.sh

# Proxy for GitHub API requests
ENV https_proxy=http://webproxy-nais.nav.no:8088

ENTRYPOINT ["/dumb-init", "--", "/entrypoint.sh"]
