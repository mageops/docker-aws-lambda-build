#!/usr/bin/env bash

set -euo pipefail

DEFAULT_PYTHON_VERSION=3.11
DEFAULT_NODEJS_VERSION=18.x

# --python-version
PYTHON_VERSION=$DEFAULT_PYTHON_VERSION
# --nodejs-version
NODEJS_VERSION=$DEFAULT_NODEJS_VERSION
# 1st arg
CODE_DIR=
# --package-name, -p
PACKAGE_NAME=
# --arch
ARCH=x86_64
# --lang
LANG=

AWS_LAMBDA_BASE_REPO=https://github.com/aws/aws-lambda-base-images

LOG_COLOR_RED=31
LOG_COLOR_GREEN=32
LOG_COLOR_YELLOW=33
LOG_COLOR_BLUE=34
LOG_COLOR_MAGENTA=35
LOG_COLOR_CYAN=36
LOG_COLOR_WHITE=37
LOG_COLOR_GREY=90

LOG_LEVEL_NAME_INFO="INFO   "
LOG_LEVEL_NAME_WARN="WARN   "
LOG_LEVEL_NAME_ERROR="ERROR  "
LOG_LEVEL_NAME_SUCCESS="SUCCESS"

CODE_SYNC_GLOBAL_EXCLUDE=(
    '/test/'
    '.git/'
    '*.md'
    '.gitignore'
    '*.zip'
)

CODE_SYNC_PYTHON_EXCLUDE=(
    '__tests__/'
    '__pycache__/'
    '*.pyc'
)

CODE_SYNC_NODEJS_EXCLUDE=(
    'node_modules/'
)

log::with_color() {
    local color=$1
    shift
    echo -e "$(log::color "$color" "$@")" >&2
}

log::with_details() {
    local color=$1
    local level=$2
    shift 2
    echo -e "$(log::color "$LOG_COLOR_GREY" "$(log::_date)") $(log::color "$LOG_COLOR_GREY" "$level") $(log::color "$color" "$@")" >&2
}

log::color() {
    local color=$1
    shift
    echo -en "\e[${color}m$@\e[0m"
}

log::_date() {
    date +"%Y-%m-%d %H:%M:%S"
}

log::info() {
    log::with_details $LOG_COLOR_BLUE "$LOG_LEVEL_NAME_INFO" "$@"
}

log::warn() {
    log::with_details $LOG_COLOR_YELLOW "$LOG_LEVEL_NAME_WARN" "$@"
}

log::error() {
    log::with_details $LOG_COLOR_RED "$LOG_LEVEL_NAME_ERROR" "$@"
}

log::success() {
    log::with_details $LOG_COLOR_GREEN "$LOG_LEVEL_NAME_SUCCESS" "$@"
}

log::stage() {
    log::with_color $LOG_COLOR_MAGENTA "   *** $@ ***"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --python-version)
            PYTHON_VERSION="$2"
            shift 2
            ;;
        --nodejs-version)
            NODEJS_VERSION="$2"
            shift 2
            ;;
        --package-name|-p)
            PACKAGE_NAME="$2"
            shift 2
            ;;
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --lang)
            LANG="$2"
            shift 2
            ;;
        *)
            CODE_DIR="$1"
            shift
            ;;
        esac
    done

    if [[ -z "$LANG" ]]; then
        echo "Error: lang is required" >&2
        print_help
        exit 1
    fi

    if [[ -z "$CODE_DIR" ]]; then
        echo "Error: code_dir is required" >&2
        print_help
        exit 1
    fi

    if [[ -z "$PACKAGE_NAME" ]]; then
        PACKAGE_NAME="$( basename $CODE_DIR)"
    fi
}

print_help() {
    echo "Usage: $(basename "$0") [options] <code_dir>"
    echo "Options:"
    echo "  --lang <lang>               Language to build (required)"
    echo "  --arch <arch>               Architecture to build for (default: $ARCH)"
    echo "  --python-version <version>  Python version to use (default: $DEFAULT_PYTHON_VERSION)"
    echo "  --nodejs-version <version>  Node.js version to use (default: $DEFAULT_NODEJS_VERSION)"
    echo "  --package-name, -p <name>   Package name (default: <code_dir>)"
}

clone_base_repo() {
    local branch=$1
    local dir=$2
    log::info "Cloning branch $branch of lambda base repo"
    if ! git clone --depth 1 --branch "$branch" "$AWS_LAMBDA_BASE_REPO" "$dir";then
        log::error "Failed to clone lambda base repo"
        log::error "Is runtime version supported?"
        exit 1
    fi
}

build_docker_image() {
    local dir=$1
    local tag=$2
    local dockerfile="$dir/$3"
    log::info "Building docker image: $tag"
    if ! docker build -t "$tag" -f "$dockerfile" "$dir"; then
        log::error "Failed to build docker image"
        exit 1
    fi
    log::success "Docker image built: $tag"
}

docker_run_script() {
    local runtime_name=$1
    local work_dir=$2
    local script=$3
    local image="mageops_lambda:$runtime_name-$ARCH"

    if ! docker run --rm -v "$work_dir:/work" -w /work \
        -u "$(id -u):$(id -g)" \
        --entrypoint sh "$image" -c "$script"; then
        log::error "Build script failed"
        exit 1
    fi
}

prepare() {
    local runtime_name=$1
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    log::stage "Cloning lambda base repo"
    clone_base_repo "$runtime_name" "$TEMP_DIR/base"
    log::stage "Building lambda base image"
    build_docker_image "$TEMP_DIR/base/$ARCH" \
        "mageops_lambda:$runtime_name-$ARCH" \
        "Dockerfile.$runtime_name"
}

sync_code() {
    local source_dir=$1
    local target_dir=$2
    local excludes=("${@:3}")
    log::stage "Syncing code to build directory"
    rsync -av --itemize-changes --delete \
        --exclude-from <(printf '%s\n' "${excludes[@]}") \
        "$source_dir" "$target_dir"
    log::success "Code synced"
}

build_package() {
    local runtime_name=$1
    local work_dir=$2
    log::stage "Creating deploy package archive"
    (
        cd "$work_dir"
        rm -vf "$PACKAGE_FILE"
        zip -qr9 "$PACKAGE_FILE" .
    )
    log::success "Package created: $PACKAGE_FILE"
}

build_python() {
    RUNTIME_NAME="python$PYTHON_VERSION"
    PACKAGE_FILE="$PACKAGE_NAME-deploy-package.$RUNTIME_NAME.zip"
    prepare "$RUNTIME_NAME"
    sync_code "$CODE_DIR" "$TEMP_DIR/build" \
        "${CODE_SYNC_GLOBAL_EXCLUDE[@]}" "${CODE_SYNC_PYTHON_EXCLUDE[@]}"
    log::stage "Building python package"
    log::info "Environment summary:"
    local docker_python_version
    docker_python_version=$(docker_run_script "$RUNTIME_NAME" "$TEMP_DIR/build" \
        "python --version")
    local docker_pip_version
    docker_pip_version=$(docker_run_script "$RUNTIME_NAME" "$TEMP_DIR/build" \
        "pip --version")
    log::info " Python: $docker_python_version"
    log::info " Pip: $docker_pip_version"
    log::info "Installing pip dependencies"
    docker_run_script "$RUNTIME_NAME" "$TEMP_DIR/build" \
        "pip install -r requirements.txt -t /work"
    log::info "Storing list of installed python deps"
    docker_run_script "$RUNTIME_NAME" "$TEMP_DIR/build" \
        "pip freeze | tee /work/requirements-built.txt"
    log::stage "Precompiling python sources"
    docker_run_script "$RUNTIME_NAME" "$TEMP_DIR/build" \
        "python -m compileall /work/"
    log::success "All done!"
    build_package "$RUNTIME_NAME" "$TEMP_DIR/build"
    mv "$TEMP_DIR/build/$PACKAGE_FILE" .
}

build_nodejs() {
    RUNTIME_NAME="nodejs$NODEJS_VERSION"
    PACKAGE_FILE="$PACKAGE_NAME-deploy-package.$RUNTIME_NAME.zip"
    prepare "$RUNTIME_NAME"
    sync_code "$CODE_DIR" "$TEMP_DIR/build" "${CODE_SYNC_GLOBAL_EXCLUDE[@]}" \
        "${CODE_SYNC_NODEJS_EXCLUDE[@]}"
    log::stage "Building nodejs package"
    log::info "Environment summary:"
    local docker_node_version
    docker_node_version=$(docker_run_script "$RUNTIME_NAME" "$TEMP_DIR/build" \
        "node --version")
    local docker_npm_version
    docker_npm_version=$(docker_run_script "$RUNTIME_NAME" "$TEMP_DIR/build" \
        "npm --version")
    log::info " Node: $docker_node_version"
    log::info " Npm: $docker_npm_version"
    log::info "Running npm install"
    docker_run_script "$RUNTIME_NAME" "$TEMP_DIR/build" \
        "npm install --production"
    log::success "All done!"
    build_package "$RUNTIME_NAME" "$TEMP_DIR/build"
    mv "$TEMP_DIR/build/$PACKAGE_FILE" .
}

main() {
    parse_arguments "$@"

    if [[ $LANG == "python" ]]; then
        build_python
    elif [[ $LANG == "nodejs" ]]; then
        build_nodejs
    else
        echo "Error: lang $LANG is not supported" >&2
        print_help
        exit 1
    fi
}

main "$@"
