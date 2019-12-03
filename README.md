You need to build the image, mount the current directory as `/build`
and execute the container. The build script should be residing in the local directory
and be named build.sh as it's automatically ran by the container (ENTRYPOINT).

```
# Build
docker build -t cs-lambda-build .
```

```
# Build the lambda zip
docker run --rm -v "$PWD":/build cs-lambda-build python name-of-your lambda
```

Where `python` is the execution environment type, currently supported are:
- python

Node support is underway...

You can also use a prebuilt image from our repo:
docker.creativestyle.pl:5050/m2c/lambda-build:latest