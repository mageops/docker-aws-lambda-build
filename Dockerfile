FROM amazonlinux:2

ARG LAMBDA_NODEJS_RELEASE="12.x"

RUN yum groups mark install "Development Tools" \
    && yum groups mark convert "Development Tools" \
    && yum groupinstall -y "Development Tools" \
    && yum -y install \
        zip \
        rsync \
        curl \
        which \
        mc \
        nano \
        coreutils \
        findutils

RUN curl --silent --location https://dl.yarnpkg.com/rpm/yarn.repo > /etc/yum.repos.d/yarn.repo \
    && rpm -Uvh https://rpm.nodesource.com/pub_${LAMBDA_NODEJS_RELEASE}/el/7/x86_64/nodesource-release-el7-1.noarch.rpm
    
RUN yum -y install \
        yarn \
        nodejs \
        nasm \
        libjpeg-devel \
        libpng-devel \
        libtiff-devel \
        libgif-devel

RUN yum -y install \
        python2 \
        python2-pip \
        python3 \
        python3-pip \
        python2-botocore \
        python2-boto3 \
        awscli \
    && pip3 install --user \
        boto3 \
        botocore
        
RUN yum -y clean all

ENV LAMBDA_NODEJS_RELEASE="$LAMBDA_NODEJS_RELEASE" \
    LAMBDA_PYTHON2_RELEASE="2.7" \
    LAMBDA_PYTHON3_RELEASE="3.7" \
    LAMBDA_BUILD_DIR="/var/app-local" \
    LAMBDA_WORK_DIR="/var/app"

COPY ./build.sh /bin/mageops-lambda-build

CMD chmod+x /bin/mageops-lambda-build \
    && mkdir -p \
        "$LAMBDA_BUILD_DIR" \
        "$LAMBDA_WORK_DIR"

WORKDIR /var/app-local

ENTRYPOINT [ "/bin/mageops-lambda-build" ]



