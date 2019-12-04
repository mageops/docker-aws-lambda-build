# MageOps Docker Container for building AWS Lambda Docker Packages

Simple, unopinionated, amamazonlinux-base contaiener that builds
deploy packages suitable for running lambdas which have custom dependencies.

PS It's on [Docker Hub](https://hub.docker.com/r/mageops/aws-lambda-build).

### Build container

```
docker build . -t mageops/aws-lambda-build
```

### Build lambda

```
docker run --rm -v "$(pwd):/var/app" mageops/aws-lambda-build python2 name-of-your-lambda
docker run --rm -v "$(pwd):/var/app" mageops/aws-lambda-build python3 name-of-your-lambda
docker run --rm -v "$(pwd):/var/app" mageops/aws-lambda-build nodejs name-of-your-lambda
docker run --rm -v "$(pwd):/var/app" mageops/aws-lambda-build nodejs-yarn name-of-your-lambda
```