FROM amazonlinux:2018.03

RUN yum -y install python27-pip zip
RUN mkdir /build
COPY ./build.sh /bin/build
CMD chmod+x /bin/build

WORKDIR "/build"
ENTRYPOINT ["/bin/build"]



