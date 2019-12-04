#!/usr/bin/env bash

set -euo pipefail

export LAMBDA_BUILD_DIR="${LAMBDA_BUILD_DIR:-/var/app-local}"
export LAMBDA_WORK_DIR="${LAMBDA_WORK_DIR:-/var/app}"

export LAMBDA_PYTHON2_RELEASE="${LAMBDA_PYTHON2_RELEASE:--unknown}"
export LAMBDA_PYTHON3_RELEASE="${LAMBDA_PYTHON3_RELEASE:--unknown}"
export LAMBDA_NODEJS_RELEASE="${LAMBDA_NODEJS_RELEASE:--unknown}"

function build_prepare() {
	echo "Copying sources to build directory"

	rsync \
		--archive \
		--verbose \
		--itemize-changes \
		--delete \
		--exclude '/test/' \
		--exclude 'node_modules/' \
		--exclude '.git/' \
		--exclude '__tests__/' \
		--exclude '__pycache__/' \
		--exclude '*.pyc' \
		--exclude '*.md' \
		"${LAMBDA_WORK_DIR}/" "${LAMBDA_BUILD_DIR}/"
}

function build_python2() {
	LAMBDA_PACKAGE_NAME="${LAMBDA_PACKAGE_NAME:-$LAMBDA_NAME.python${LAMBDA_PYTHON2_RELEASE}}"

	echo "*** Start python2 build ***"
	echo "--- Python: $(python2 --version) ($(which python2))"
	echo "--- Pip: $(pip2 --version) ($(which pip2))"

	echo "*** Install python requirements ***"
	pip2 install -r requirements.txt -t "$LAMBDA_BUILD_DIR"

	ls -al
	echo "*** Store list of installed python deps ***"
	PYTHONPATH="$LAMBDA_BUILD_DIR" pip2 freeze -r requirements.txt --local | tee "$LAMBDA_BUILD_DIR/requirements-built.txt"

	echo "*** Precompile python sources ***"
	(python2 -m compileall "$LAMBDA_BUILD_DIR/" || echo "--- Ignore compilation errors and continue...")
}

function build_python3() {
	LAMBDA_PACKAGE_NAME="${LAMBDA_PACKAGE_NAME:-$LAMBDA_NAME.python${LAMBDA_PYTHON3_RELEASE}}"

	echo "*** Start python3 build ***"
	echo "--- Python: $(python3 --version) ($(which python3))"
	echo "--- Pip: $(pip3 --version) ($(which pip3))"

	echo "*** Install python requirements ***"
	pip3 install -r requirements.txt -t "$LAMBDA_BUILD_DIR"

	echo "*** Store list of installed python deps ***"
	pip3 freeze | tee "$LAMBDA_BUILD_DIR/requirements-built.txt"

	echo "*** Precompile python sources ***"
	(python3 -m compileall "$LAMBDA_BUILD_DIR/" || echo "--- Ignore compilation errors and continue...")
}

function build_nodejs_npm() {
	LAMBDA_PACKAGE_NAME="${LAMBDA_PACKAGE_NAME:-$LAMBDA_NAME.nodejs${LAMBDA_NODEJS_RELEASE}}"

	echo "*** Start nodejs build using npm ***"
	echo "--- Node: $(node --version) ($(which node))"
	echo "--- Npm:  $(npm --version) ($(which npm))"

	echo "*** Run npm install ***"
	npm install --production
}

function build_nodejs_yarn() {
	LAMBDA_PACKAGE_NAME="${LAMBDA_PACKAGE_NAME:-$LAMBDA_NAME.nodejs${LAMBDA_NODEJS_RELEASE}}"

	echo "*** Start nodejs build using yarn ***"
	echo "--- Node: $(node --version) ($(which node))"
	echo "--- Yarn: $(yarn --version) ($(which yarn))"

	echo "*** Running yarn default script ***"
	yarn --prod
}

function build_trim() {
	echo "*** Trimm build files ***"

	find "${LAMBDA_BUILD_DIR}" \
		-type d -name '.git' -or \
		-type d -iname '__tests__' -or \
		-type f -iname '*.md' \
			| xargs -I{dir} rm -rvf {dir} 
}

function build_package() {
	echo "*** Create deploy package archive ***"

	pushd "${LAMBDA_BUILD_DIR}"
		rm -vf "${LAMBDA_NAME}.*.zip"
		zip -r9 "${LAMBDA_WORK_DIR}/${LAMBDA_PACKAGE_NAME}.zip" .
	popd
}

function show_help() {
echo -e "\
Usage: $(basename "$0") <env_type> <lambda_release_name> [custom_build_command]\n\
\n\
Available env types:\n\
  - python2       (python$LAMBDA_PYTHON2_RELEASE) \n\
  - python3       (python$LAMBDA_PYTHON3_RELEASE) \n\
  - nodejs        (nodejs$LAMBDA_NODEJS_RELEASE) \n\
  - nodejs-yarn   (nodejs$LAMBDA_NODEJS_RELEASE)\
" >&2
}

if [[ $# -lt 2 ]] ; then
	show_help
	exit 1
fi

export LAMBDA_ENV_TYPE="$1"
export LAMBDA_NAME="${2:-deploy-package}"

shift 2

export LAMBDA_CUSTOM_BUILD_CMD="$@"

echo "--- Host: $(uname -a)"

case "$LAMBDA_ENV_TYPE" in
    "python2")             LAMBDA_BUILD="python2" ;;
    "python3")             LAMBDA_BUILD="python3" ;;
	"nodejs")              LAMBDA_BUILD="nodejs_npm" ;;
	"nodejs-yarn")         LAMBDA_BUILD="nodejs_yarn" ;;
    *)                     echo -e "Error - unknown lambda environemnt type: $LAMBDA_ENV_TYPE\n" >&2 && show_help && exit 9 ;;
esac

build_prepare

pushd "${LAMBDA_BUILD_DIR}/"
build_$LAMBDA_BUILD

if [[ ! -z "$LAMBDA_CUSTOM_BUILD_CMD" ]] ; then
	echo "*** Run custom command: $LAMBDA_CUSTOM_BUILD_CMD ***"
	command $LAMBDA_CUSTOM_BUILD_CMD
fi
popd

build_trim
build_package

echo "*** Build finished succesfully! 🎉 ***"
echo "--- Artifact: 📦 ${LAMBDA_PACKAGE_NAME}.zip"
