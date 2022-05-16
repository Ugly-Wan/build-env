FROM alpine:3.15

ARG TF_VER=1.1.9
ARG HOME_DIR=/home/appuser

RUN apk add --update --no-cache \
    shadow \
    bash \
    curl \
    git \
    python3 \
    sshpass \
    openssh-client \
    openssl \
    ca-certificates \
    yq

RUN python3 -m ensurepip &&\
    pip3 install --no-cache --upgrade pip setuptools && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/python3-config /usr/bin/python-config && \
    ln -sf /usr/bin/pydoc3 /usr/bin/pydoc && \
    ln -sf /usr/bin/pip3 /usr/bin/pip

RUN apk add --no-cache --virtual .build-deps \
    gcc

RUN addgroup -S appgroup && adduser -S appuser -G appgroup -s /bin/bash

USER appuser

WORKDIR $HOME_DIR

ENV PATH="$HOME_DIR/.tfenv/bin:$HOME_DIR/.local/bin:$HOME_DIR/.ovftoolfiles/vmware-ovftool:$PATH"

RUN git clone https://github.com/tfutils/tfenv.git ~/.tfenv && \
    tfenv install $TF_VER && \
    tfenv use $TF_VER

USER root

RUN apk add --no-cache --virtual .build-deps \
    gcc \
    musl-dev \
    libffi-dev \
    python3-dev && \
    su appuser -c "python -m pip install --user ansible paramiko" &&\
    apk del .build-deps

ARG OVFTOOL_FILENAME=VMware-ovftool-4.4.0-15722219-lin.x86_64.bundle
ADD $OVFTOOL_FILENAME /tmp/

RUN wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.32-r0/glibc-2.32-r0.apk && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.32-r0/glibc-bin-2.32-r0.apk && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.32-r0/glibc-i18n-2.32-r0.apk && \
    apk add glibc-2.32-r0.apk glibc-bin-2.32-r0.apk glibc-i18n-2.32-r0.apk && \
    /usr/glibc-compat/bin/localedef -i en_GB -f UTF-8 en_GB.UTF-8 && \
    rm -f glibc-2.32-r0.apk glibc-bin-2.32-r0.apk glibc-i18n-2.32-r0.apk && \
    apk add --no-cache --virtual .build-deps \
    coreutils \
    libgcc && \
    chmod +x /tmp/$OVFTOOL_FILENAME && \
    /bin/sh /tmp/$OVFTOOL_FILENAME --console --eulas-agreed --required && \
    rm -f /tmp/$OVFTOOL_FILENAME && \
    apk del .build-deps

# Env setup
ENV PACKER_VERSION=1.8.0\
    PACKER_OSNAME=linux \
    PACKER_OSARCH=amd64 \
    PACKER_DEST=/usr/local/sbin

# Packer path setup
ENV PACKER_ZIPFILE=packer_${PACKER_VERSION}_${PACKER_OSNAME}_${PACKER_OSARCH}.zip

# Install packer in path
ADD https://releases.hashicorp.com/packer/${PACKER_VERSION}/${PACKER_ZIPFILE} ${PACKER_DEST}/
RUN unzip ${PACKER_DEST}/${PACKER_ZIPFILE} -d ${PACKER_DEST} && \
    rm -rf ${PACKER_DEST}/${PACKER_ZIPFILE}

USER appuser

RUN ansible-galaxy collection install onepassword.connect

ENTRYPOINT [ "bash" ]