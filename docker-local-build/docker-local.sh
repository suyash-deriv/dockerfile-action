#!/usr/bin/env bash


#############################################################################################################################################################################################
#                                                                                                                                                                                           #
# Description       : This script serves the purpose of building, and pushing Docker Images.                                                                                                #
# Author            : Team DevOps (Kubernetes)                                                                                                                                              #
# Version           : 2024.01.001                                                                                                                                                           #
# Created           : 18/Jan/2024                                                                                                                                                           #
# Last Update       : Jan 2024                                                                                                                                                              #
# Script Location   : https://github.com/arun-ms-deriv/dockerfile-action/blob/main/docker-local.sh                                                                                          #
# WikiJs Link       : <Need to update later>                                                                                                                                                #
#                                                                                                                                                                                           #
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#                                                                                                                                                                                           #
# Syntax : ./docker-local.sh [-di|--docker-image <Docker_Image>] [-du|--docker-username <Docker_Username>] [-dp|--docker-password <Docker_Password>] \                                      #
#                            [-df|--docker-file <Docker_File>] [-ds|--docker-scan <true/false>] [-dpu|--docker-push <true/false>] \                                                         #
#                            [-dc|--docker-context <test_path>] [-dc|--project-type <perl/python/go/node/skip>] [-f|--force]                                                                #
#                                                                                                                                                                                           #
#                            -di (or) --docker-image     # Docker full image name (required)                                                                                                #
#                            -du (or) --docker-username  # username used to login against the Docker registry (optional / required if in case of push set to true)                          #
#                            -dp (or) --docker-password  # Password or personal access token used to login against the Docker registry (optional / required if in case of push set to true) #
#                            -df (or) --docker-file      # Path to the Dockerfile (required)                                                                                                #
#                            -ds (or) --docker-scan      # Boolean if we want to Scan the Docker image. Default: false (optional)                                                           #
#                            -dpu(or) --docker-push      # Boolean to represent if we want to Push image to a Docker registry Default: false (optional)                                     #
#                            -dc (or) --docker-context   # Build's context is the set of files located in the specified PATH or URL (optional)                                              #
#                            -pt (or) --project-type     # Type of the project: python, node, go or perl. Use skip to ignore this check (optional)                                          #
#                            -dpf(or) --dependency-file  # Project Dependency file path (optional)                                                                                          #
#                            -f  (or) --force            # Force with no-prompt (optional)                                                                                                  #
#                            -d  (or) --debug            # Enable Debug Mode (optional)                                                                                                     #
#                                                                                                                                                                                           #
# Example   : ./docker-local.sh -di testimage:latest -du docker_username -dp ******* -df ./Dockerfile -ds false -dpu false -dc ./context.txt -pt skip --force                               #
#                                                                                                                                                                                           #
#############################################################################################################################################################################################

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
export DOCKER_BUILD_PLATFORM="linux/amd64"
export LOG_RETENTION="15"

# Defaults / Can be overridden from arguments
export FORCE="false"
export PROJECT_TYPE="skip"
export DOCKER_CONTEXT=""
export DEPENDENCY_FILE=""


# Color Codes Declarations
export REDC='\033[0;31m'
export GREENC='\033[0;32m'
export YELLOWC='\033[1;33m'
export NOC='\033[0m' # No Color


# Temporary Files Clean-up
temp_cleanup() {
    #rm -rf "${TEMP_DIR}" > /dev/null 2>&1
    find "${TEMP_DIR}/" -type f -name "*.log" -mtime "+${LOG_RETENTION}" -exec rm -rvf {} \; 2>/dev/null || echo
    echo -e "Remove logs older than ${LOG_RETENTION} under ${TEMP_DIR}/*.log"
}


# Auto Clean-up Temp Directory on Exit (Un-Comment if required to auto clean-up logs directory on exit)
## function exit_cleanup() {
##     temp_cleanup
##     echo
## }
## trap exit_cleanup EXIT


# Output Divider
pattern_divider() {
    COLUMNS=$(tput cols 2>/dev/null); if [ -z "$COLUMNS" ]; then COLUMNS="100"; fi; printf "\r%*s\r%s\n" $COLUMNS "#" "#" | tr " " "-"
}


# Logger
logger() {
    TYPE="${1}"
    LOG_MSG="${2}"
    case "${TYPE}" in
        info)
            echo -e "[$(date +'%Y-%m-%d %H:%M:%S %Z %z')] ${NOC}[INFO]${NOC}\t : $LOG_MSG" | tee -a "${LOG_FILE}";;
        success|0)
            echo -e "[$(date +'%Y-%m-%d %H:%M:%S %Z %z')] ${GREENC}[SUCCESS]${NOC}: $LOG_MSG" | tee -a "${LOG_FILE}" ;;
        warning)
            echo -e "[$(date +'%Y-%m-%d %H:%M:%S %Z %z')] ${YELLOWC}[WARNING]${NOC}: $LOG_MSG" | tee -a "${LOG_FILE}" ;;
        error|[1-9]|[1-9][1-9]|[1-9][1-9][1-9])
            echo -e "[$(date +'%Y-%m-%d %H:%M:%S %Z %z')] ${REDC}[ERROR]${NOC}: $LOG_MSG" | tee -a "${LOG_FILE}"; exit 1;;
     esac
}


# Input Values Pre-Check
input_usage() {
    pattern_divider
    echo -e "\nHelp\t\t: ./$(basename $0) [-h|--help] (Display help message)\n"
    echo -e "\nInput Usage\t: ./$(basename $0) [-di|--docker-image <Docker_Image>] [-du|--docker-username <Docker_Username>] [-dp|--docker-password <Docker_Password>] \\
                                    [-df|--docker-file <Docker_File>] [-ds|--docker-scan <true/false>] [-dpu|--docker-push <true/false>] \\
                                    [-dc|--docker-context <true/false>] [-dc|--project-type <true/false>] [-f|--force]\n
                -di (or) --docker-image     # Docker full image name (required)
                -du (or) --docker-username  # username used to login against the Docker registry (optional)
                -dp (or) --docker-password  # Password or personal access token used to login against the Docker registry (optional)
                -df (or) --docker-file      # Path to the Dockerfile (required)
                -ds (or) --docker-scan      # Boolean if we want to Scan the Docker image. Default: false (optional)
                -dpu(or) --docker-push      # Boolean to represent if we want to Push image to a Docker registry (optional)
                -dc (or) --docker-context   # Build's context is the set of files located in the specified PATH or URL (optional)
                -pt (or) --project-type     # Type of the project: python, node, go or perl. Use skip to ignore this check (optional)
                -dpf(or) --dependency-file  # Project Dependency file path (optional)
                -f  (or) --force            # Force with no-prompt (optional)
                -d  (or) --debug            # Enable Debug Mode (optional)\n"
    echo -e "\nExample\t\t: ./docker-local.sh -di testimage:latest -du docker_username -dp ******* -df ./Dockerfile -ds false -dpu false -dc ./context.txt -pt skip --force"
    echo; pattern_divider; echo && exit 1;
}


# Function to check project type and validate it's dependencies
validate_project_dependency() {
    check_dependency_file() {
        if [ -f "$'{DEPENDENCY_FILE}" ]; then
            logger "info" "${PROJECT_TYPE} dependency file '${DEPENDENCY_FILE}' found"
        else
            echo "${PROJECT_TYPE} dependency file '${DEPENDENCY_FILE}' not found."
            if find . -iname "${DEPENDENCY_FILE}" -print | grep -q .; then
                find . -iname "${DEPENDENCY_FILE}" -print
                logger "warning" "Dependency file found in subdirectory. Update the relative path in the Dockerfile."
            fi
            logger "warning" "${PROJECT_TYPE} dependency file '${DEPENDENCY_FILE}' not found"
        fi
    }
    case "${PROJECT_TYPE}" in
        python) dependent_file="requirements.txt"; check_dependency_file "${dependent_file}" ;;
        node) dependent_file="package.json"; check_dependency_file "${dependent_file}" ;;
        go) dependent_file="go.mod"; check_dependency_file "${dependent_file}" ;;
        perl) dependent_file="cpanfile"; check_dependency_file "${dependent_file}" ;;
        custom) dependent_file="${DEPENDENCY_FILE}"; check_dependency_file "${dependent_file}" ;;
        skip) echo "Skipping dependency validation" ;;
        *) echo "No dependency file found for project type: ${PROJECT_TYPE}. Supported project types: python, go, node, or perl. Set project_type as skip to ignore this test." && exit 1 ;;
    esac
}


# Docker Install / status check
docker_check(){
    if ! docker info &> /dev/null; then logger "error" "Error: Docker is not installed / daemon is not running or not accessible."; fi
    logger "$?" "Docker Install / Running Check"
}


# Docker Lint
docker_lint() {
    docker run --rm -i "${DOCKER_LINT_IMAGE}" < "${DOCKER_FILE}"
    logger "$?" "Docker Lint"
}


# Docker Build
docker_build() {
    docker buildx create --use
    docker build --platform "${DOCKER_BUILD_PLATFORM}" --file "${DOCKER_FILE}" --tag "${DOCKER_IMAGE}" .
    logger "$?" "Docker Build"
}


# Docker Tag
docker_tag() {
    docker tag "${DOCKER_IMAGE}" "${DOCKER_REGISTRY}/${DOCKER_IMAGE}"
    if [[ "${DOCKER_REGISTRY}" == "docker.io" ]]; then
        DOCKER_TAG_FULL="${DOCKER_IMAGE}"
    else
        DOCKER_TAG_FULL="${DOCKER_REGISTRY}/${DOCKER_IMAGE}"
    fi
    docker images ${DOCKER_TAG_FULL} --format table
    logger "$?" "Docker Tag - ${DOCKER_TAG_FULL}"
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
    if [ $# -eq 0 ]; then input_usage; exit 1; fi
    while [ $# -gt 0 ]; do
        case "$1" in
            -di|--docker-image)
                case "$2" in
                    -*) echo -e "${YELLOWC}Missing Parameter:${NOC} -di|--docker-image <Docker Image>"; input_usage ;;
                    *) if [ -z "$2" ]; then echo -e "${YELLOWC}Missing Parameter: ${NOC} -di|--docker-image requires a docker image name. Example [my-app:latest / my-app:$(date +'%Y.%m.00.001')]"; input_usage; fi; export DOCKER_IMAGE=$2; shift 2 ;;
                esac
                ;;
            -du|--docker-username)
                case "$2" in
                    -*) echo -e "${YELLOWC}Missing Parameter:${NOC} -du|--docker-username <docker_username>"; input_usage ;;
                    *) if [ -z "$2" ]; then echo -e "${YELLOWC}Missing Parameter:${NOC} [Example: -du <docker_username> ]"; input_usage; fi; export DOCKER_USERNAME=$2; shift 2 ;;
                esac
                ;;
            -dp|--docker-password)
                case "$2" in
                    -*) echo -e "${YELLOWC}Missing Parameter:${NOC} -dp|--docker-password <docker_password>"; input_usage ;;
                    *) if [ -z "$2" ]; then echo -e "${YELLOWC}Missing Parameter:${NOC} [Example: -dp <docker_password> ]"; input_usage; fi; export DOCKER_PASSWORD=$2; shift 2 ;;
                esac
                ;;
            -df|--docker-file)
                case "$2" in
                    -*) echo -e "${YELLOWC}Missing Parameter:${NOC} -df|--docker-file <docker_file>"; input_usage ;;
                    *) if [ -z "$2" ]; then echo -e "${YELLOWC}Missing Parameter:${NOC} [Example: -df <file> ]"; input_usage; fi; export DOCKER_FILE=${2:-./Dockerfile}; shift 2 ;;
                esac
                ;;
            -ds|--docker-scan)
                case "$2" in
                    -*) echo -e "${YELLOWC}Missing Parameter:${NOC} -ds|--docker-scan <docker_scan>"; input_usage ;;
                    *) if [ -z "$2" ]; then echo -e "${YELLOWC}Missing Parameter:${NOC} [Example: -ds <docker_scan> ]"; input_usage; fi; export DOCKER_SCAN=${2:-false}; shift 2 ;;
                esac
                ;;
            -dpu|--docker-push)
                 case "$2" in
                    -*) echo -e "${YELLOWC}Missing Parameter:${NOC} -dpu|--docker-push <docker_push>"; input_usage ;;
                    *) if [ -z "$2" ]; then echo -e "${YELLOWC}Missing Parameter:${NOC} [Example: -dpu <docker_push> ]"; input_usage; fi; export DOCKER_PUSH=${2:-false}; shift 2 ;;
                esac
                ;;
            -pt|--project-type)
                case "$2" in
                    -*) echo -e "${YELLOWC}Missing Parameter:${NOC} -pt|--project-type"; input_usage ;;
                    *) if [ -z "$2" ]; then echo -e "${YELLOWC}Missing Parameter:${NOC} -pt|--project-type"; input_usage; fi; export PROJECT_TYPE=${2:-unknown}; shift 2 ;;
                esac
                ;;
            -dc|--docker-context)
                case "$2" in
                    -*) echo -e "${YELLOWC}Missing Parameter:${NOC} -dc|--docker-context <docker_context>"; input_usage ;;
                    *) if [ -z "$2" ] || [ ! -s "$2" ]; then echo -e "${YELLOWC}Missing Parameter:${NOC} [Example: -dc <docker_context> ]"; input_usage; fi; export DOCKER_CONTEXT=${2-""}; shift 2 ;;
                esac
                ;;
            -dpf|--dependency-file)
                case "$2" in
                    -*) echo -e "${YELLOWC}Missing Parameter:${NOC} -dpf|--dependency-file <dependency_file>"; input_usage ;;
                    *) if [ -z "$2" ] || [ ! -s "$2" ]; then echo -e "${YELLOWC}Missing Parameter:${NOC} [Example: -dc <dependency_file> ]"; input_usage; fi; export DEPENDENCY_FILE=${2-""}; shift 2 ;;
                esac
                ;;
            -f|--force)
                export FORCE="true"
                shift
                ;;
            -d|--debug)
                export DEBUG="true"
                shift
                ;;
            -h|--help)
                input_usage;
                ;;
            *)
                echo; echo -e "${YELLOWC}The input parameters are not valid. Please refer below syntax${NOC}"
                input_usage;
                ;;
        esac
    done
}


# Function to Confirm User Input
confirm_user_input() {
    while true; do
        echo; echo -e "${YELLOWC}Are you sure do you want to Proceed with Docker Build with inputs below?${NOC}";
        echo -e "\nDOCKER_IMAGE\t: ${GREENC}${DOCKER_IMAGE}${NOC}
DOCKER_USERNAME\t: ${GREENC}${DOCKER_USERNAME}${NOC}
DOCKER_PASSWORD\t: ${GREENC}***********${NOC}
DOCKER_FILE\t: ${GREENC}${DOCKER_FILE}${NOC}
DOCKER_SCAN\t: ${GREENC}${DOCKER_SCAN}${NOC}
DOCKER_PUSH\t: ${GREENC}${DOCKER_PUSH}${NOC}
PROJECT_TYPE\t: ${GREENC}${PROJECT_TYPE}${NOC}
DOCKER_CONTEXT\t: ${GREENC}${DOCKER_CONTEXT}${NOC}
DEPENDENCY_FILE\t: ${GREENC}${DEPENDENCY_FILE}${NOC}"
echo; echo -e "Enter \"${GREENC}y${NOC}\" or \"${GREENC}n${NOC}\""; echo
        read YES_NO_USER && echo ""
        case "$YES_NO_USER" in
            ([yY][eE][sS]|[yY]) break; ;;
            ([nN][oO]|[nN])     echo; echo -e "${YELLOWC}Exiting...${NOC}"; echo; temp_cleanup && exit ;;
            *) echo; echo "Please answer Yes(y) or No(n)" ;;
        esac
    done
}


# Main Program - Executes the below functions in sequence order.
echo; echo -e "${GREENC}####### ${YELLOWC}Docker Local Setup Tool${GREENC} #######${NOC}"; echo
input_usage_fetch "$@"
if [[ ${DEBUG} == "true" ]]; then set -Eeuxo pipefail; fi
export readonly TEMP_DIR="${WORKSPACE_DIR}/docker_local_tool_logs";
temp_cleanup
mkdir -p "${TEMP_DIR}" && export LOG_FILE="${TEMP_DIR}/build-${BUILD_TIME}.log"
logger "info" "Log File Created: ${LOG_FILE}"
if [[ "${FORCE}" != "true" ]]; then confirm_user_input; fi
##validate_dependency # Disabled / Need to discuss further on this
pattern_divider
docker_check
pattern_divider
docker_lint
pattern_divider
validate_project_dependency
pattern_divider
docker_build
pattern_divider
docker_tag
pattern_divider
docker_scan "${DOCKER_SCAN}"
pattern_divider
docker_push "${DOCKER_PUSH}"
pattern_divider


#****************************************************************** End of Script ********************************************************************#
