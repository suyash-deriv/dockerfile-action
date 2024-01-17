#!/bin/bash

set -euxo pipefail

# Dockerfile Check, Build and Push

# Set input variables
DOCKER_IMAGE="${1}"             # Docker Image Name
PUSH="${2:-false}"              # Boolean to represent if we want to Push image to a Docker registry
DOCKER_USERNAME="${3}"          # Boolean to represent if we want to Push image to a Docker registry
DOCKER_PASSWORD="${4}"          # Password or personal access token used to log against the Docker registry
DOCKERFILE="${5:-./Dockerfile}" # Path to the Dockerfile
CONTEXT="${6:-.}"               # Build's context is the set of files located in the specified PATH or URL
PROJECT_TYPE="${7:-unknown}"    # Type of the project: python, node, go or perl. Use skip to ignore this check.
DOCKER_SCAN="${8:-false}"

# Function to check project dependencies
check_dependency_file() {
    local dependency_file="${CONTEXT}/${1}"
    if [ -f "$'{dependency_file}" ]; then
        echo "${PROJECT_TYPE} dependency file '${dependency_file}' found."
    else
        echo "${PROJECT_TYPE} dependency file '${dependency_file}' not found."
        if find . -iname "${dependency_file}" -print | grep -q .; then
            echo "Dependency file found in subdirectory. Update the relative path in the Dockerfile."
            find . -iname "${dependency_file}" -print
            exit 1
        fi
        exit 1
    fi
}


validate_dependency() {
    # Check project type and validate dependencies
    case "${PROJECT_TYPE}" in
        "python") dependent_file="requirements.txt"; check_dependency_file "${dependent_file}" ;;
        "node") dependent_file="package.json"; check_dependency_file "${dependent_file}" ;;
        "go") dependent_file="go.mod"; check_dependency_file "${dependent_file}" ;;
        "perl") dependent_file="cpanfile"; check_dependency_file "${dependent_file}" ;;
        "skip") echo "Skipping dependency validation" && : ;;
        *) echo "No dependency file found for project type: ${PROJECT_TYPE}. Supported project types: python, go, node, or perl. Set project_type as skip to ignore this test." && exit 1 ;;
    esac
}

# Docker Lint
docker_lint() {
    docker run --rm -i hadolint/hadolint < "${DOCKERFILE}"
}


# Docker Build
docker_build() {
    docker buildx create --use
    DOCKER_BUILD_RESULT=$(docker buildx build --load --file "${DOCKERFILE}" --tag "${DOCKER_IMAGE}" "$CONTEXT")
}


# Docker Install / status check
docker_check(){
    if ! docker info &> /dev/null; then echo "Error: Docker is not installed / daemon is not running or not accessible."; fi
}


# Docker Image Scan post build
docker_scan() {
    if [ "${DOCKER_SCAN}" = "true" ]; then
        docker run --rm aquasecurity/trivy-action:master image-ref="${DOCKER_IMAGE}:${DOCKER_BUILD_RESULT##*:}" scan-type=image format="table" exit-code="1" ignore-unfixed=true vuln-type="os,library" severity="CRITICAL,HIGH" hide-progress=true scanners="vuln,secret,config"
    fi
}


# Docker Push to Registry
docker_push() {
    if [ "${PUSH}" == "true" ]; then
        echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin
        docker buildx build --file "${DOCKERFILE}" --push --tag "${CONTEXT}"
    fi
}


# Main Function
main_start() {
    validate_dependency
    docker_lint
    docker_build
    docker_check
    docker_scan
    docker_push
}


# Main Function Start
main_start
