

### Build container

```
docker build . -t mageops/aws-lambda-build
```

### Build lambda

```
docker run --rm -v "$(PWD):/var/app" mageops/aws-lambda-build python2 name-of-your-lambda
docker run --rm -v "$(PWD):/var/app" mageops/aws-lambda-build python3 name-of-your-lambda
docker run --rm -v "$(PWD):/var/app" mageops/aws-lambda-build nodejs name-of-your-lambda
docker run --rm -v "$(PWD):/var/app" mageops/aws-lambda-build nodejs-yarn name-of-your-lambda
```