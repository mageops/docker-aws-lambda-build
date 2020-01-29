#!/usr/bin/env bash

set -euo pipefail

export LAMBDA_BUILD_DIR="${LAMBDA_BUILD_DIR:-/var/app-local}"
export LAMBDA_WORK_DIR="${LAMBDA_WORK_DIR:-/var/app}"

export LAMBDA_BUILD_HOOK_POST_BUILD="${LAMBDA_POST_BUILD_SCRIPT:-.lambda-build-hook/post-build.sh}"
export LAMBDA_BUILD_HOOK_PRE_BUILD="${LAMBDA_PRE_BUILD_SCRIPT:-.lambda-build-hook/pre-build.sh}"

# Directory where custom shared libraries shall be placed in order to be loaded automatically.
export LAMBDA_SHARED_LIB_DIR="${LAMBDA_SHARED_LIB_DIR:-${LAMBDA_WORK_DIR}/lib}"

export LAMBDA_PYTHON2_RELEASE="${LAMBDA_PYTHON2_RELEASE:--unknown}"
export LAMBDA_PYTHON3_RELEASE="${LAMBDA_PYTHON3_RELEASE:--unknown}"
export LAMBDA_NODEJS_RELEASE="${LAMBDA_NODEJS_RELEASE:--unknown}"

function log_stage() { echo -e "\n\e[35m***\e[0m \e[33m$@\e[0m \e[35m***\e[0m\n"; }
function log_info() { echo -e "\e[35m---\e[0m \e[34m$@\e[0m"; }

function build_prepare() {
	log_stage "Sync sources to build directory"

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

	log_stage "Start python2 build"
	log_info "Python: $(python2 --version) ($(which python2))"
	log_info "Pip: $(pip2 --version) ($(which pip2))"

	log_stage "Install python requirements"
	pip2 install -r requirements.txt -t "$LAMBDA_BUILD_DIR"

	ls -al
	log_stage "Store list of installed python deps"
	PYTHONPATH="$LAMBDA_BUILD_DIR" pip2 freeze -r requirements.txt --local | tee "$LAMBDA_BUILD_DIR/requirements-built.txt"

	log_stage "Precompile python sources"
	python2 -m compileall "$LAMBDA_BUILD_DIR/"
}

function build_python3() {
	LAMBDA_PACKAGE_NAME="${LAMBDA_PACKAGE_NAME:-$LAMBDA_NAME.python${LAMBDA_PYTHON3_RELEASE}}"

	log_stage "Start python3 build"
	log_info "Python: $(python3 --version) ($(which python3))"
	log_info "Pip: $(pip3 --version) ($(which pip3))"

	log_stage "Install python requirements"
	pip3 install -r requirements.txt -t "$LAMBDA_BUILD_DIR"

	log_stage "Store list of installed python deps"
	pip3 freeze | tee "$LAMBDA_BUILD_DIR/requirements-built.txt"

	log_stage "Precompile python sources"
	python3 -m compileall "$LAMBDA_BUILD_DIR/"
}

function build_nodejs_npm() {
	LAMBDA_PACKAGE_NAME="${LAMBDA_PACKAGE_NAME:-$LAMBDA_NAME.nodejs${LAMBDA_NODEJS_RELEASE}}"

	log_stage "Start nodejs build using npm"
	log_info "Node: $(node --version) ($(which node))"
	log_info "Npm:  $(npm --version) ($(which npm))"

	log_stage "Run npm install"
	npm install --production
}

function build_nodejs_yarn() {
	LAMBDA_PACKAGE_NAME="${LAMBDA_PACKAGE_NAME:-$LAMBDA_NAME.nodejs${LAMBDA_NODEJS_RELEASE}}"

	log_stage "Start nodejs build using yarn"
	log_info "Node: $(node --version) ($(which node))"
	log_info "Yarn: $(yarn --version) ($(which yarn))"

	log_stage "Running yarn default script"
	yarn --prod
}

function build_trim() {
	log_stage "Trim build files"

	find "${LAMBDA_BUILD_DIR}" \
		-type d -name '.git' -or \
		-type d -iname '__tests__' -or \
		-type f -iname '*.md' \
			| xargs -I{dir} rm -rvf {dir}
}

function build_package() {
	log_stage "Create deploy package archive"

	pushd "${LAMBDA_BUILD_DIR}"
		rm -vf "${LAMBDA_NAME}.*.zip"
		zip -qr9 "${LAMBDA_WORK_DIR}/${LAMBDA_PACKAGE_NAME}.zip" .
	popd
}


function build_hook_pre_build() {
	if [[ -x "${LAMBDA_BUILD_HOOK_PRE_BUILD}" ]] ; then
		log_stage "Executing custom pre build script: ${LAMBDA_BUILD_HOOK_PRE_BUILD}"
		"./${LAMBDA_BUILD_HOOK_PRE_BUILD}"
	else
		log_info "Skipping absent custom pre build script: ${LAMBDA_BUILD_HOOK_PRE_BUILD}"
	fi
}

function build_hook_post_build() {
	if [[ -x "${LAMBDA_BUILD_HOOK_POST_BUILD}" ]] ; then
		log_stage "Executing custom post build script: ${LAMBDA_BUILD_HOOK_POST_BUILD}"
		"./${LAMBDA_BUILD_HOOK_POST_BUILD}"
	else
		log_info "Skipping absent custom post build script: ${LAMBDA_BUILD_HOOK_POST_BUILD}"
	fi
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

log_info "Host: $(uname -a)"

case "$LAMBDA_ENV_TYPE" in
    "python2")             LAMBDA_BUILD="python2" ;;
    "python3")             LAMBDA_BUILD="python3" ;;
		"nodejs")              LAMBDA_BUILD="nodejs_npm" ;;
		"nodejs-yarn")         LAMBDA_BUILD="nodejs_yarn" ;;
    *)                     echo -e "Error - unknown lambda environemnt type: $LAMBDA_ENV_TYPE\n" >&2 && show_help && exit 9 ;;
esac

build_prepare

pushd "${LAMBDA_BUILD_DIR}/"
build_hook_pre_build
build_$LAMBDA_BUILD

if [[ ! -z "$LAMBDA_CUSTOM_BUILD_CMD" ]] ; then
	log_stage "Run custom command: $LAMBDA_CUSTOM_BUILD_CMD"
	command $LAMBDA_CUSTOM_BUILD_CMD
fi

build_hook_post_build
popd

build_custom
build_trim
build_package

log_stage "Build finished succesfully! 🎉"
log_info "Artifact: 📦 ${LAMBDA_PACKAGE_NAME}.zip"

