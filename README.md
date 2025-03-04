# Opinionated Custom JupyterLab Stack Container

An easy-to-maintain and modern JupyterLab environment built with Pixi (instead of Conda/Mamba). This container is designed to make it quick and easy to spin up jupyterlab with all my favorite tools, while keeping everything up to date.

## Features

- **Modern Package Management**: Utilizes [Pixi](https://github.com/prefix-dev/pixi) for fast environment creation and reliable dependency management.
- **Standard Base Image**: Based on the official Ubuntu image (`ubuntu:latest`) to provide familiarity and broad compatibility.
- **Up-to-date**: Pulls updates for the Ubuntu image, Pixi binary, and Python packages (as defined in `pixi.toml`) during each build.
- **Pre-configured Extensions**: Includes JupyterLab extensions (`jupyterlab_execute_time`, `ipyflow`) that provide useful enhancements to the notebook interface.
- **Automated Testing & Lock File Generation**: GitHub Actions regularly rebuild the container, execute smoke tests (checking imports for key Python libraries like NumPy, Pandas, and scikit-learn), and regenerate the `pixi.lock` file to record exact dependency versions, ensuring we always have the latest working versions.
- **Built for ARM64**: Built natively for ARM64, ensuring compatibility with Apple Silicon.

## Quick Start

Clone the repository and run:

```bash
docker compose build
docker compose up
```

JupyterLab will be available at:

```
http://localhost:8888
```

By default, token/password authentication is disabled for convenience during local development. (Do **not** use this configuration in production.)

## Project Structure

```
.
├── .dockerignore
├── .github
│   ├── release-drafter.yml
│   └── workflows
│       ├── ci-cd.yml
│       └── release-drafter.yml
├── Dockerfile
├── LICENSE
├── README.md
├── docker-compose.yml
├── pixi.toml
├── pixi.lock
└── start.sh
```

*Note:* The file `pixi.lock` is generated automatically during every build, capturing exact versions of all installed dependencies.

## Dependency Management

Environment dependencies are defined in `pixi.toml`:

- **Modify package versions here:** Edit `pixi.toml` to add, remove, or adjust dependencies.
- **Latest Versions on Every Build:** The container fetches the most current versions from external sources during builds. For example, the Dockerfile queries GitHub's API to download the latest Pixi binary, and the Ubuntu base image is always pulled using the `latest` tag.
- **Lock File Snapshot:** Every build regenerates `pixi.lock`, capturing exact versions of all dependencies installed. This helps you track changes over time and pin specific dependencies as needed.

### Manually Generating `pixi.lock`

If the automated build pipeline ever fails, you can manually generate the latest `pixi.lock` file by running:

```bash
docker build -t pixi_jupyter_container:latest .

docker create --name temp-container pixi_jupyter_container:latest
docker cp temp-container:/home/jovyan/pixi.lock ./pixi.lock
docker rm temp-container
```

Then commit the updated `pixi.lock` file:

```bash
git add pixi.lock
git commit -m "Manually update pixi.lock"
git push
```

## GitHub Container Registry (GHCR)

Built images are automatically tagged and pushed to GHCR on every commit:

- **Commit SHA Tag:**  
  ```
  ghcr.io/<your-username>/pixi_jupyter_container:<commit-sha>
  ```
- **Release Tag:**  
  ```
  ghcr.io/<your-username>/pixi_jupyter_container:<git-tag>
  ```

## CI/CD Workflow

The GitHub Actions workflow automates:

- **Scheduled Builds:** Regularly triggered container builds keep the environment current.
- **Container Testing:** Automated health checks and smoke tests verify essential Python libraries (NumPy, Pandas, scikit-learn) import successfully.
- **Lock File Generation:** The workflow regenerates `pixi.lock` each build, providing a snapshot of installed dependency versions.
- **Security Scanning:** Utilizes [Trivy](https://github.com/aquasecurity/trivy) to detect vulnerabilities.
- **Publishing Images:** Automatically tags and publishes container images to GHCR.

## Releases and Changelog

Releases are automatically drafted, and changelogs are generated through [Release Drafter](https://github.com/release-drafter/release-drafter). See the [GitHub Releases](../../releases) page for detailed changelogs and release notes.

## Advanced Usage

### Adding or Removing Packages

1. **Edit `pixi.toml`:** Add new dependencies under `[dependencies]` or `[pypi-dependencies]`.
2. **Rebuild the Container:**
   ```bash
   docker compose build --no-cache
   docker compose up
   ```
3. **Verify:** Ensure the new libraries import correctly (e.g., `import your_package`).

### Changing Python Versions

To switch Python to another version (e.g., `3.12.*`), edit `pixi.toml`:

```toml
[dependencies]
python = "3.12.*"
```

Then rebuild and test as described above.

### Customizing JupyterLab

- **Themes:** Customize themes directly within JupyterLab's settings or by installing compatible theme extensions.
- **Extensions:** Add extensions to `pixi.toml` (Conda) or `[pypi-dependencies]` (PyPI).

## Troubleshooting

### JupyterLab Not Accessible  

- Check if the container is running:
  ```bash
  docker ps
  ```
- Inspect container logs for errors:
  ```bash
  docker logs <container-name>
  ```

### Cannot Install a New Package with Pixi  

- Modify `pixi.toml` and rebuild the container as shown in [Advanced Usage](#adding-or-removing-packages).
- If rebuild fails, manually regenerate `pixi.lock` as described above.

### Slow I/O on macOS  

- Use Docker Desktop file sharing optimizations by adding `:delegated` or `:cached` flags to volume mounts in `docker-compose.yml`:
  ```yaml
  volumes:
    - ~/code:/home/jovyan/work:delegated
  ```

### Environment Out of Sync  

- Delete the existing `pixi.lock`, then regenerate it:
  ```bash
  pixi lock && pixi install
  ```

## Volume Mounts (Customizing Your Environment)

By default, the provided `docker-compose.yml` mounts common directories (e.g., `~/.ssh`, `~/Downloads`, `~/Documents`, and `~/git`) to match typical workflows. Modify these mounts to fit your specific directory structure or personal workflow preferences.

Example adjustment:

```yaml
volumes:
  - ~/.ssh:/home/jovyan/.ssh
  - ~/code:/home/jovyan/work:rw
```

Change these paths as needed for your environment.

## License

Distributed under the MIT License. See `LICENSE` for more information.
