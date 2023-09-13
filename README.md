# MageOps Docker Container for building AWS Lambda Docker Packages
Build script to create AWS Lambda packages for Python and NodeJS 10.x

### Build lambda

```bash
./build.sh --lang python --python-version 3.11 -p package-name ./package-dir
./build.sh --lang nodejs --nodejs-version 10.x -p package-name ./package-dir
```
