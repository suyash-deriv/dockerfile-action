# dockerfile-action

# Dockerfile Standard Checks Workflow

## Usage

To onboard this workflow into your project, follow these steps:

1. Create a `.github/workflows` directory in your project repository if it doesn't already exist.

2. Create a new YAML file, e.g., `docker_build.yml`, inside the `.github/workflows` directory.

3. Copy and paste the following content into `dockerfile_checks.yml`:

```yaml
name: Dockerfile Standard Checks

on:
  push:
    branches: [main]

jobs:
  standard-checks:
    runs-on: ubuntu-22.04
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Check and build Docker Image
        uses: suyash-deriv/dockerfile-action@main
        with:
          images: suyashderiv/sample-app
          push: false
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_password }}
          project_type: python
```

4. Save the changes to the repository.

5. Ensure that you have the necessary Docker registry credentials (Docker username and password) set as GitHub secrets. 
    - Replace `${{ secrets.DOCKER_USERNAME }}` and `${{ secrets.DOCKER_password }}` in the workflow with your actual secret names.

6. Push the changes to the `main` branch of your repository.

7. The workflow will now be automatically triggered on each push to the `main` branch, and it will check your Dockerfile and, if configured, build a Docker image.

## Configuration

You can customize the workflow by modifying the `with` section of the "Check and build Docker Image" step in the YAML file. Here are some key parameters you can adjust:


| Field          | Allowed Values                         | Mandatory |
|----------------|---------------------------------------|-----------|
| `images`       | Replace with your Docker image name   |   ✔️     |
| `push`         | `true` (to push to registry), `false` (otherwise) |   ✔️     |
| `dockerfile`   | Path to your Dockerfile (e.g., `./`)  |   ❌     |
| `context`      | Directory where Dockerfile is present |   ❌     |
| `username`     | Replace with your Docker registry username |   ✔️     |
| `password`     | Replace with your Docker registry password |   ✔️     |
| `project_type` | Customizable project type: `python`, `go`, `perl`, `node`, etc. |   ❌     |


Use `project_type`: skip if your project type is not applicable to any of the above.