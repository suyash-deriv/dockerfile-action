# Docker Local Build

## Usage on your Local Workstation

### Syntax:
```
./docker-local.sh [-di|--docker-image <Docker_Image>] [-du|--docker-username <Docker_Username>] [-dp|--docker-password <Docker_Password>]
                           [-df|--docker-file <Docker_File>] [-ds|--docker-scan <true/false>] [-dpu|--docker-push <true/false>]
                           [-dc|--docker-context <test_path>] [-dc|--project-type <perl/python/go/node/skip>] [-f|--force]
                            -di (or) --docker-image     # Docker full image name (required)
                            -du (or) --docker-username  # username used to login against the Docker registry (optional / required if in case of push set to true)
                            -dp (or) --docker-password  # Password or personal access token used to login against the Docker registry (optional / required if in case of push set to true) #
                            -df (or) --docker-file      # Path to the Dockerfile (required)
                            -ds (or) --docker-scan      # Boolean if we want to Scan the Docker image. Default: false (optional)
                            -dpu(or) --docker-push      # Boolean to represent if we want to Push image to a Docker registry Default: false (optional)
                            -dc (or) --docker-context   # Build's context is the set of files located in the specified PATH or URL (optional)
                            -pt (or) --project-type     # Type of the project: python, node, go or perl. Use skip to ignore this check (optional)
                            -dpf(or) --dependency-file  # Project Dependency file path (optional)
                            -f  (or) --force            # Force with no-prompt (optional)
                            -d  (or) --debug            # Enable Debug Mode (optional)
```
### Example:
```
./docker-local.sh -di testimage:latest -du docker_username -dp ******* -df ./Dockerfile -ds false -dpu false -dc ./context.txt -pt skip --force

```