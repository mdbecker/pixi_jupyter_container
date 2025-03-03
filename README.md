# Opinionated Custom JupyterLab Stack Container

An optimized, easy-to-maintain, and modern JupyterLab environment built with Pixi (instead of Conda/Mamba). This container is designed for efficient data science workflows and always pulls the latest bleeding-edge versions of all external dependencies at build time.

## Features

- **Modern Package Management**: Utilizes [Pixi](https://github.com/prefix-dev/pixi) for fast environment creation and dependency management.
- **Minimal and Efficient**: Based on Ubuntu 24.04 (or latest) for smaller, faster containers.
- **Bleeding-Edge Updates**: Always fetches the latest Ubuntu image, Pixi binary, and Python packages (as defined in `pixi.toml`) during each build.
- **Pre-configured Extensions**: Includes popular JupyterLab extensions (`jupyterlab_execute_time`, `ipyflow`) for improved productivity.
- **Stylish Out-of-the-Box**: Pre-themed with JupyterThemes (Monokai style).
- **Automated Testing & Lock File Generation**: GitHub Actions automatically rebuild the container on a regular schedule, run smoke tests (including checks for essential Python libraries like NumPy, Pandas, and scikit-learn), and generate an updated `pixi.lock` file that captures the resolved versions.
- **Built for ARM64**: Optimized for Apple Silicon (M1/M2 MacBooks).

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

By default, token/password authentication is disabled for convenience in local development. (Do **not** use this configuration in production.)

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
├── ci-cd.yml
├── docker-compose.yml
├── pixi.toml
├── pixi.lock
└── start.sh
```

*Note:* The file `pixi.lock` is generated automatically during every build to capture the exact versions of all installed dependencies.

## Dependency Management

Environment dependencies are defined in `pixi.toml`:

- **Modify package versions here:** Edit `pixi.toml` to add, remove, or adjust dependencies.
- **Latest Versions on Every Build:** The container always pulls the most up-to-date versions from external sources. For example, the Dockerfile downloads the latest Pixi binary by querying GitHub’s API, and the Ubuntu base image is referenced without a fixed digest.
- **Lock File Snapshot:** Every build regenerates `pixi.lock` so you can see exactly which versions were installed. This allows you to review changes over time and pin any dependencies if needed.

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

## Scheduled Builds and Latest Dependencies

The container is rebuilt on a regular schedule to always pull the latest and greatest versions of all external dependencies. In particular:

- **Dynamic Dockerfile Updates:** The Ubuntu base image is referenced without a fixed digest (or with a broad tag like `ubuntu:24.04`), ensuring new updates are always fetched.
- **Latest Pixi Binary:** The Dockerfile queries the GitHub API for the latest Pixi release and downloads that binary.
- **Python Packages:** The version constraints in `pixi.toml` are kept broad to allow the newest compatible versions.
- **Scheduled Rebuilds:** A cron schedule in the GitHub Actions workflow triggers periodic container builds (e.g., every Monday at 3:00 AM UTC), ensuring your environment remains current.

## CI/CD Workflow

The GitHub Actions workflow handles:

- **Scheduled Builds:** In addition to push and pull request triggers, a cron schedule (e.g., `0 3 * * 1`) automatically triggers container builds.
- **Container Testing:** Automated tests include a Docker healthcheck and smoke tests that verify critical Python libraries (like NumPy, Pandas, and scikit-learn) import correctly.
- **Lock File Generation:** The workflow always regenerates `pixi.lock` on every build, providing a snapshot of the installed dependency versions.
- **Security Scanning:** Uses [Trivy](https://github.com/aquasecurity/trivy) for vulnerability scanning.
- **Publishing Images:** Automatically tags and pushes container images to GHCR.

## Releases and Changelog

Releases are automatically drafted and changelogs are generated through [Release Drafter](https://github.com/release-drafter/release-drafter). See the [GitHub Releases](../../releases) page for detailed changelogs and release notes.

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

- **Themes:** The container includes JupyterThemes (Monokai by default). Change the theme inside JupyterLab’s settings or run:
  ```bash
  jt -t monokai
  ```
- **Extensions:** Add extensions to `pixi.toml` (if available via Conda) or to the `[pypi-dependencies]` section (if available via PyPI).

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
- If the rebuild fails, manually regenerate `pixi.lock` as described above.

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

## Maintenance & Contribution

- **Dependency Updates:**  
  The container always pulls the latest versions during scheduled builds. The generated `pixi.lock` file provides a snapshot of what is installed; if a build fails, you can choose to pin a dependency in `pixi.toml`.
- **Testing:**  
  The CI/CD pipeline automatically tests changes before deployment.
- **Contributions:**  
  Contributions are welcome! Feel free to open issues or pull requests to improve this stack.

## License

Distributed under the MIT License. See `LICENSE` for more information.
