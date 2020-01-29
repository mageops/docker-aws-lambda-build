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

### Custom build hook scripts

In case you need to perform any custom commands pre/post the dependency installation (core build step)
just create executable shell scripts (make sure they have executable permission!) and place them in:
 - `.lambda-build-hook/pre-build.sh`
 - `.lambda-build-hook/post-build.sh`

### Installing custom shared libraries

Sometimes the core system images lacks certain libraries. Fortunately the default 
`LD_LIBRARY_PATH` in lambda runtime env contains `$LAMBDA_TASK_ROOT/lib` path
so shared libs placed in `lib` subdirectory are loaded automatically when needed. 

_*Note that system-wide library dirs are prioritized* on the library path thus 
it's not possible to override system libraries this way, only add missing ones.
You can force usage of your custom libraries by overriding the `LD_LIBRARY_PATH` 
environment variable in lambda configuration though._

The best way to install shared libs is to copy them in post-build hook script,
you can also make sure appropriate libs are installed via `yum`.

Example `.lambda-build-hook/post-build.sh` script which installs `libjpeg-turbo`:

```
#!/usr/bin/env bash
yum -y install libjpeg-turbo
mkdir -pv "${LAMBDA_SHARED_LIB_DIR}"
cp -v /usr/lib64/libjpeg.so.* "${LAMBDA_SHARED_LIB_DIR}"
```
