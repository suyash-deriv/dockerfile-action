#!/usr/bin/env bash

##set -Eeuxo pipefail

###################################################################################################################################################################################
#                                                                                                                                                                                 #
# Description       : This script serves the purpose of building, and pushing Docker Images.                                                                                      #
# Author            : Team DevOps (Kubernetes)                                                                                                                                    #
# Version           : 2024.01.001                                                                                                                                                 #
# Created           : 18/Jan/2024                                                                                                                                                 #
# Last Update       : Jan 2024                                                                                                                                                    #
# Script Location   : https://github.com/arun-ms-deriv/dockerfile-action/blob/main/docker-local.sh                                                                                #
# WikiJs Link       :                                                                                                                                                             #
#                                                                                                                                                                                 #
#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#                                                                                                                                                                                 #
# Syntax : ./docker-local.sh [-di|--docker-image] <Docker_Image> [-du|--docker-username] <Docker_Username> [-dp|--docker-password)] <Docker_Password> \                           #
#                            [-df|--docker-file)] <Docker_File> [-ds|--docker-scan )] <true/false> [-dpu|--docker-push)] <true/false> \                                           #
#                            [-dc|--docker-context)] <true/false> [-dc|--project-type)] <true/false> [-f|--force]                                                                 #
#                                                                                                                                                                                 #
#                            -di (or) --docker-image     # Docker full image name                                                                                                 #
#                            -du (or) --docker-username  # username used to login against the Docker registry                                                                     #
#                            -dp (or) --docker-password  # Password or personal access token used to login against the Docker registry                                            #
#                            -df (or) --docker-file      # Path to the Dockerfile                                                                                                 #
#                            -ds (or) --docker-scan      # Boolean if we want to Scan the Docker image. Default: false                                                            #
#                            -dpu(or) --docker-push      # Boolean to represent if we want to Push image to a Docker registry                                                     #
#                            -dc (or) --docker-context   # Build's context is the set of files located in the specified PATH or URL                                               #
#                            -pt (or) --project-type     # Type of the project: python, node, go or perl. Use skip to ignore this check                                           #
#                            -f  (or) --force            # Force with no-prompt                                                                                                   #
#                                                                                                                                                                                 #
# Example   : ./docker-local.sh -di testimage:latest -du docker_username -dp ******* -df ./Dockerfile -ds false -dpu false -dc ./context.txt -pt skip --force                     #
#                                                                                                                                                                                 #
###################################################################################################################################################################################

#****************************************************************** Start of Script ********************************************************************#


# Constants Declarations
##export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin
export LC_ALL="en_US.UTF-8"
export CURRENT_DATE_TIME=$(date +'%m_%d_%Y--%H_%M_%S')
export BUILD_TIME=$(date '+%Y%m%d_%H%M')
export WORKSPACE_DIR="$(dirname $(readlink -f $0))"
export DOCKER_REGISTRY="docker.io"
export DOCKER_LINT_IMAGE="hadolint/hadolint:latest"
export DOCKER_SCAN_IMAGE="aquasecurity/trivy-action:master"


# Color Codes Declarations
export REDC="\033[0;31m"
export GREENC="\033[0;32m"
export YELLOWC="\033[1;33m"
export NOC="\033[0m" # No Color


# Temporary Files Clean-up
temp_cleanup() {
    rm -rf "${TEMP_DIR}" > /dev/null 2>&1
}


# Auto Clean-up Temp Directory on Exit
function exit_cleanup() {
    ##temp_cleanup
    echo
}
trap exit_cleanup EXIT


# Output Divider
pattern_divider() {
    COLUMNS=$(tput cols 2>/dev/null); if [ -z "$COLUMNS" ]; then COLUMNS="100"; fi; printf "\n\r%*s\r%s\n" $COLUMNS "#" "#" | tr " " "-"
}


# Logger
logger() {
    TYPE="${1}"
    LOG_MSG="${2}"
    case "${TYPE}" in
        info)
            echo "[$(date +'%Y-%m-%d %H:%M:%S %Z %z')] [INFO] : $LOG_MSG" ;;
        success|0)
            echo "[$(date +'%Y-%m-%d %H:%M:%S %Z %z')] [SUCCESS] : $LOG_MSG" ;;
        warning)
            echo "[$(date +'%Y-%m-%d %H:%M:%S %Z %z')] [WARNING] : $LOG_MSG" ;;
        error|[1-9]|[1-9][1-9]|[1-9][1-9][1-9])
            echo "[$(date +'%Y-%m-%d %H:%M:%S %Z %z')] [ERROR] : $LOG_MSG" ;;
     esac
}


# Input Values Pre-Check
input_usage() {
    pattern_divider
    printf "\nHelp\t\t: ./$(basename $0) [-h|--help] (Display help message)\n"
    printf "\nInput Usage\t: ./$(basename $0) [-di|--docker-image] <Docker_Image> [-du|--docker-username] <Docker_Username> [-dp|--docker-password)] <Docker_Password> \\
                         [-df|--docker-file)] <Docker_File> [-ds|--docker-scan )] <true/false> [-dpu|--docker-push)] <true/false> \\
                         [-dc|--docker-context)] <true/false> [-dc|--project-type)] <true/false> [-f|--force]\n"
    printf "\nExample\t\t: ./docker-local.sh -di testimage:latest -du docker_username -dp ******* -df ./Dockerfile -ds false -dpu false -dc ./context.txt -pt skip --force\n"
    echo; pattern_divider; echo && exit 1;
}


# Function to check project dependencies
check_dependency_file() {
    local dependency_file="${DOCKER_CONTEXT}/${1}"
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
        python) dependent_file="requirements.txt"; check_dependency_file "${dependent_file}" ;;
        node) dependent_file="package.json"; check_dependency_file "${dependent_file}" ;;
        go) dependent_file="go.mod"; check_dependency_file "${dependent_file}" ;;
        perl) dependent_file="cpanfile"; check_dependency_file "${dependent_file}" ;;
        custom) dependent_file="cpanfile"; check_dependency_file "${dependent_file}" ;;
        skip) echo "Skipping dependency validation" ;;
        *) echo "No dependency file found for project type: ${PROJECT_TYPE}. Supported project types: python, go, node, or perl. Set project_type as skip to ignore this test." && exit 1 ;;
    esac
}


# Docker Install / status check
docker_check(){
    if ! docker info &> /dev/null; then logger "error" "Error: Docker is not installed / daemon is not running or not accessible."; fi
    logger "$?" "Docker Check"
}


# Docker Lint
docker_lint() {
    docker run --rm -i "${DOCKER_LINT_IMAGE}" < "${DOCKER_FILE}"
    logger "$?" "Docker Lint"
}


# Docker Build and Tag
docker_build_tag() {
    ##docker buildx create --use
    docker build --load --file "${DOCKER_FILE}" --tag "${DOCKER_IMAGE}" .
    logger "$?" "Docker Build"
}


# Docker Image Scan post build
docker_scan() {
    if [ "${1}" == "true" ]; then
        docker run --rm "${DOCKER_SCAN_IMAGE}" image-ref="${DOCKER_IMAGE}:${DOCKER_BUILD_RESULT##*:}" scan-type=image format="table" exit-code="1" ignore-unfixed=true vuln-type="os,library" severity="CRITICAL,HIGH" hide-progress=true scanners="vuln,secret,config"
        logger "$?" "Docker Scan"
    else
        logger "info" "Docker Scan Skipped as input is set to false"
    fi
}


# Docker Push to Registry
docker_push() {
    if [ "${1}" == "true" ]; then
        echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin
        logger "$?" "Docker Login"
        docker buildx build --file "${DOCKER_FILE}" --push --tag "${DOCKER_CONTEXT}"
        logger "$?" "Docker Push"
    else
        logger "info" "Docker Push Skipped as input is set to false"
    fi
}


# Fetching Input Details
input_usage_fetch() {
    if [ $# -eq 0 ]; then printf "Help:\t\t${WORKSPACE_DIR}/$(basename $0) [-h|--help] (Display help message)\n\n"; exit 1; fi
    while [ $# -gt 0 ]; do
        case "$1" in
            -di|--docker-image)
                case "$2" in
                    -*) echo "${YELLOWC}Missing Parameter:${NOC} -di|--docker-image <Docker Image>"; input_usage ;;
                    *) if [ -z "$2" ]; then echo "${YELLOWC}Missing Parameter: ${NOC} -di|--docker-image requires a docker image name. Example [my-app:latest / my-app:$(date +'%Y.%m.00.001')]"; input_usage; fi; export DOCKER_IMAGE=$2; shift 2 ;;
                esac
                ;;
            -du|--docker-username)
                case "$2" in
                    -*) echo "${YELLOWC}Missing Parameter:${NOC} -du|--docker-username <docker_username>"; input_usage ;;
                    *) if [ -z "$2" ]; then echo "${YELLOWC}Missing Parameter:${NOC} [Example: -du <docker_username> ]"; input_usage; fi; export DOCKER_USERNAME=$2; shift 2 ;;
                esac
                ;;
            -dp|--docker-password)
                case "$2" in
                    -*) echo "${YELLOWC}Missing Parameter:${NOC} -dp|--docker-password <docker_password>"; input_usage ;;
                    *) if [ -z "$2" ]; then echo "${YELLOWC}Missing Parameter:${NOC} [Example: -dp <docker_password> ]"; input_usage; fi; export DOCKER_PASSWORD=$2; shift 2 ;;
                esac
                ;;
            -df|--docker-file)
                case "$2" in
                    -*) echo "${YELLOWC}Missing Parameter:${NOC} -df|--docker-file <docker_file>"; input_usage ;;
                    *) if [ -z "$2" ]; then echo "${YELLOWC}Missing Parameter:${NOC} [Example: -df <file> ]"; input_usage; fi; export DOCKER_FILE=${2:-./Dockerfile}; shift 2 ;;
                esac
                ;;
            -ds|--docker-scan)
                case "$2" in
                    -*) echo "${YELLOWC}Missing Parameter:${NOC} -ds|--docker-scan <docker_scan>"; input_usage ;;
                    *) if [ -z "$2" ]; then echo "${YELLOWC}Missing Parameter:${NOC} [Example: -ds <docker_scan> ]"; input_usage; fi; export DOCKER_SCAN=${2:-false}; shift 2 ;;
                esac
                ;;
            -dpu|--docker-push)
                 case "$2" in
                    -*) echo "${YELLOWC}Missing Parameter:${NOC} -dpu|--docker-push <docker_push>"; input_usage ;;
                    *) if [ -z "$2" ]; then echo "${YELLOWC}Missing Parameter:${NOC} [Example: -dpu <docker_push> ]"; input_usage; fi; export DOCKER_PUSH=${2:-false}; shift 2 ;;
                esac
                ;;
            -pt|--project-type)
                case "$2" in
                    -*) echo "${YELLOWC}Missing Parameter:${NOC} -pt|--project-type"; input_usage ;;
                    *) if [ -z "$2" ]; then echo "${YELLOWC}Missing Parameter:${NOC} -pt|--project-type"; input_usage; fi; export PROJECT_TYPE=${2:-unknown}; shift 2 ;;
                esac
                ;;
            -dc|--docker-context)
                case "$2" in
                    -*) echo "${YELLOWC}Missing Parameter:${NOC} -dc|--docker-context <docker_context>"; input_usage ;;
                    *) if [ -z "$2" ] || [ ! -s "$2" ]; then echo "${YELLOWC}Missing Parameter:${NOC} [Example: -dc <docker_context> ]"; input_usage; fi; export DOCKER_CONTEXT=${2-""}; shift 2 ;;
                esac
                ;;
            -f|--force) FORCE="true"
                shift
                ;;
            -h|--help)
                input_usage;
                ;;
            *)
                echo; echo "The input parameters are not valid. Please refer below syntax."
                input_usage;
                ;;
        esac
    done
}


# Function to Confirm User Input
confirm_user_input() {
    while true; do
        echo; echo "Are you sure do you want to Proceed with Docker Build with inputs below?";
        echo -e "\nDOCKER_IMAGE\t: ${DOCKER_IMAGE}
DOCKER_USERNAME\t: ${DOCKER_USERNAME}
DOCKER_PASSWORD\t: ***********
DOCKER_FILE\t: ${DOCKER_FILE}
DOCKER_SCAN\t: ${DOCKER_SCAN}
DOCKER_PUSH\t: ${DOCKER_PUSH}
PROJECT_TYPE\t: ${PROJECT_TYPE}
DOCKER_CONTEXT\t: ${DOCKER_CONTEXT}"
echo; echo "Enter \"y\" or \"n\""; echo
        read YES_NO_USER && echo ""
        case "$YES_NO_USER" in
            ([yY][eE][sS]|[yY]) break; ;;
            ([nN][oO]|[nN])     echo; echo "${YELLOWC}Exiting...${NOC}"; echo; temp_cleanup && exit ;;
            *) echo; echo "Please answer Yes(y) or No(n)" ;;
        esac
    done
}


# Main Program - Executes the below functions in sequence order.
echo; echo "####### Docker Local Setup Tool #######"; echo
input_usage_fetch "$@"
export readonly TEMP_DIR="${WORKSPACE_DIR}/docker_local_tool_archive";
temp_cleanup
mkdir -p "${TEMP_DIR}" && export LOG_FILE="${TEMP_DIR}/build.log"
logger "info" "Log File Created: ${LOG_FILE}"
if [[ "$FORCE" != "true" ]]; then confirm_user_input; fi
##validate_dependency # Disabled / Need to discuss further on this
pattern_divider
docker_check
pattern_divider
docker_lint
pattern_divider
docker_build_tag
pattern_divider
docker_scan "${DOCKER_SCAN}"
pattern_divider
docker_push "${DOCKER_PUSH}"


#****************************************************************** End of Script ********************************************************************#
