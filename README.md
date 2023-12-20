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
          project_type: py
```

4. Save the changes to the repository.

5. Ensure that you have the necessary Docker registry credentials (Docker username and password) set as GitHub secrets. Replace `${{ secrets.DOCKER_USERNAME }}` and `${{ secrets.DOCKER_password }}` in the workflow with your actual secret names.

6. Push the changes to the `main` branch of your repository.

7. The workflow will now be automatically triggered on each push to the `main` branch, and it will check your Dockerfile and, if configured, build a Docker image.

## Configuration

You can customize the workflow by modifying the `with` section of the "Check and build Docker Image" step in the YAML file. Here are some key parameters you can adjust:

- `images`: Replace `suyashderiv/sample-app` with the name of your Docker image.
- `push`: Set this to `true` if you want to push the Docker image to a registry; otherwise, set it to `false`.
- `username` and `password`: Replace `${{ secrets.DOCKER_USERNAME }}` and `${{ secrets.DOCKER_password }}` with your Docker registry credentials.
- `project_type`: Customize this parameter according to your project's needs. Can be any one of the following.
        - py
        - go
        - perl
        - node
    use `project_type`: skip if your project type is not applicable to any of the above.