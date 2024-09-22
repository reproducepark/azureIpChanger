FROM mcr.microsoft.com/azure-cli:cbl-mariner2.0

ENV DEBIAN_FRONTEND=noninteractive

RUN tdnf install -y jq openssh-clients sshpass && \
    tdnf clean all

COPY script.sh /usr/local/bin/script.sh

WORKDIR /usr/local/bin

RUN chmod +x ./script.sh
