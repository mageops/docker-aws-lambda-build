FROM amazonlinux:2023

ARG LAMBDA_NODEJS_RELEASE="20.x"

RUN dnf -y groups mark install "Development Tools" \
    && dnf -y groupinstall -y "Development Tools" \
    && dnf -y install --allowerasing \
        zip \
        rsync \
        which \
        findutils \
        curl \
    && dnf -y clean all

RUN dnf install -y https://rpm.nodesource.com/pub_${LAMBDA_NODEJS_RELEASE}/nodistro/repo/nodesource-release-nodistro-1.noarch.rpm

RUN dnf -y install \
        nodejs \
        nasm \
        libjpeg-devel \
        libpng-devel \
        libtiff-devel \
    && dnf -y clean all \
    && npm i -g yarn

RUN dnf -y install \
        python3 \
        python3-pip \
        awscli \
    && pip3 install --user \
        boto3 \
        botocore \
    && dnf -y clean all

ENV LAMBDA_NODEJS_RELEASE="$LAMBDA_NODEJS_RELEASE" \
    LAMBDA_PYTHON3_RELEASE="3.9.x" \
    LAMBDA_BUILD_DIR="/var/app-local" \
    LAMBDA_WORK_DIR="/var/app"

COPY ./build.sh /bin/mageops-lambda-build

CMD chmod+x /bin/mageops-lambda-build \
    && mkdir -p \
        "$LAMBDA_BUILD_DIR" \
        "$LAMBDA_WORK_DIR"

WORKDIR /var/app-local

ENTRYPOINT [ "/bin/mageops-lambda-build" ]
