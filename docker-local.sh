#!/bin/bash

set -euxo pipefail

# Dockerfile Check, Build and Push

# Set input variables
DOCKER_IMAGE="${1}"             # Docker Image Name
PUSH="${2:-false}"              # Boolean to represent if we want to Push image to a Docker registry
DOCKER_USERNAME="${3}"          # Boolean to represent if we want to Push image to a Docker registry
PASSWORD="${4}"                 # Password or personal access token used to log against the Docker registry
DOCKERFILE="${5:-./Dockerfile}" # Path to the Dockerfile
CONTEXT="${6:-.}"               # Build's context is the set of files located in the specified PATH or URL
PROJECT_TYPE="${7:-unknown}"    # Type of the project: python, node, go or perl. Use skip to ignore this check.

# Function to check project dependencies
check_dependency_file() {
    local dependency_file="$CONTEXT/$1"
    if [ -f "$dependency_file" ]; then
        echo "$PROJECT_TYPE dependency file '$dependency_file' found."
    else
        echo "$PROJECT_TYPE dependency file '$dependency_file' not found."
        if find . -iname "$dependency_file" -print | grep -q .; then
            echo "Dependency file found in subdirectory. Update the relative path in the Dockerfile."
            find . -iname "$dependency_file" -print
            exit 1
        fi
        exit 1
    fi
}

# Check project type and validate dependencies
case "$PROJECT_TYPE" in
    "python") dependent_file="requirements.txt"; check_dependency_file "$dependent_file" ;;
    "node") dependent_file="package.json"; check_dependency_file "$dependent_file" ;;
    "go") dependent_file="go.mod"; check_dependency_file "$dependent_file" ;;
    "perl") dependent_file="cpanfile"; check_dependency_file "$dependent_file" ;;
    "skip") echo "Skipping dependency validation" && : ;;
    *) echo "No dependency file found for project type: $PROJECT_TYPE. Supported project types: python, go, node, or perl. Set project_type as skip to ignore this test." && exit 1 ;;
esac

# Check Docker Installed / Running or not.
if ! docker info &> /dev/null; then echo "Error: Docker is not installed / daemon is not running or not accessible."; fi

# Run linter for Dockerfile
docker run --rm -i hadolint/hadolint:v3.1.0 < "$DOCKERFILE"

# Set up Docker Buildx
docker buildx create --use

# Docker meta
DOCKER_META=$(docker run --rm --entrypoint /usr/bin/env docker/metadata-action:v5 images="${DOCKER_IMAGE}" tags="type=ref,event=branch type=ref,event=pr type=ref,event=tag type=sha,format=long,prefix=")

# Login to GitHub Container Registry if pushing is required
if [ "$PUSH" == "true" ]; then
    echo "$PASSWORD" | docker login -u "${DOCKER_USERNAME}" --password-stdin
fi

# Build without pushing
DOCKER_BUILD_RESULT=$(docker buildx build --load --file "$DOCKERFILE" --tag "$DOCKER_META" "$CONTEXT")

# Run Trivy vulnerability scanner
docker run --rm aquasecurity/trivy-action:master image-ref="${DOCKER_IMAGE}:${DOCKER_BUILD_RESULT##*:}" scan-type=image format="table" exit-code="1" ignore-unfixed=true vuln-type="os,library" severity="CRITICAL,HIGH" hide-progress=true scanners="vuln,secret,config"

# Push image if required
if [ "$PUSH" == "true" ]; then
    docker buildx build --file "$DOCKERFILE" --push --tag "$DOCKER_META" "$CONTEXT"
fi
