[![Docker Hub Build Status](https://img.shields.io/docker/cloud/build/mageops/aws-lambda-build?label=Docker+Image+Build)](https://hub.docker.com/r/mageops/aws-lambda-build/builds)
# MageOps Docker Container for building AWS Lambda Docker Packages

Simple, unopinionated, amamazonlinux-base contaiener that builds
deploy packages suitable for running lambdas which have custom dependencies.

PS It's on [Docker Hub](https://hub.docker.com/r/mageops/aws-lambda-build).

### Build container

#### Build using defaults (w/nodejs12.x)

```bash
docker build . -t mageops/aws-lambda-build
```

#### Build w/nodejs10.x (still required for Cloudfront Edge Lambdas)

```bash
docker build . -t mageops/aws-lambda-build:nodejs10.x --build-arg LAMBDA_NODEJS_RELEASE=10.x
```

### Build lambda

```bash
docker run --rm -v "$(pwd):/var/app" mageops/aws-lambda-build python2 name-of-your-lambda
docker run --rm -v "$(pwd):/var/app" mageops/aws-lambda-build python3 name-of-your-lambda
docker run --rm -v "$(pwd):/var/app" mageops/aws-lambda-build nodejs name-of-your-lambda
docker run --rm -v "$(pwd):/var/app" mageops/aws-lambda-build nodejs-yarn name-of-your-lambda
```
