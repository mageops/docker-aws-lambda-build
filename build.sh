#!/usr/bin/env bash

set -e

BUILD_DIR=/tmp/build
WORK_DIR=$PWD
TYPE="$1"
NAME="$2"

function build_python() {
	echo "Building python lambda ${NAME}..."
	echo "Installing requirements from requirements.txt..."
	pip install -r requirements.txt -t $BUILD_DIR
	cp *.py $BUILD_DIR
}

mkdir $BUILD_DIR

case "$TYPE" in
    "python")              build_python ;;
    *)                     echo "Unknown lambda environemnt type, supported: python" >&2; exit 1 ;;
esac

cd $BUILD_DIR

echo "Creating zipfile $NAME.zip..."
zip -r "$WORK_DIR/$NAME.zip" .
