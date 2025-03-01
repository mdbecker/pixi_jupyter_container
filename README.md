# Opinionated Custom Jupyter Stack Container

An optimized, easy-to-maintain, and modern Jupyter Notebook environment built with Pixi instead of Conda/Mamba. Designed specifically for efficient data science workflows.

## Features

- **Modern Package Management**: Utilizes [Pixi](https://github.com/prefix-dev/pixi) and UV for fast environment creation and dependency management.
- **Minimal and Efficient**: Based on Ubuntu 24.04 minimal image for smaller, faster containers.
- **Pre-configured Extensions**: Includes popular Jupyter extensions (execute time, table beautifier, code prettify, execution dependencies, Python markdown).
- **Stylish Out-of-the-Box**: Pre-themed with JupyterThemes (Monokai style).
- **Automated Updates & Testing**: GitHub Actions automatically handle dependency updates, container testing (including smoke tests for essential Python libraries like NumPy, Pandas, and scikit-learn), lock file generation, and continuous container deployment.
- **Built for ARM64**: Optimized for Apple Silicon (M1/M2 MacBooks).

## Quick Start

Clone the repository and run:

```bash
docker-compose build
docker-compose up
```

Jupyter will be available at:

```
http://localhost:8888
```

By default, token/password authentication is disabled for convenience in local development.

## Project Structure

```
.
├── Dockerfile
├── docker-compose.yml
├── pixi.toml
├── pixi.lock
├── renovate.json
├── start.sh
├── README.md
└── .github/
    └── workflows/
        └── ci-cd.yml
```

## Dependency Management

Environment dependencies are managed in `pixi.toml`:

- Modify package versions here.
- The CI/CD workflow automatically generates and updates `pixi.lock`.

### Manually Generating pixi.lock

If the automated pipeline ever fails, you can manually generate the latest `pixi.lock` file and copy it out using:

```bash
docker build --target env-builder -t pixi-env-builder .
docker create --name temp-container pixi-env-builder
docker cp temp-container:/tmp/pixi.lock ./pixi.lock
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

- Tagged with commit SHA: `ghcr.io/<your-username>/pixi_jupyter_container:<commit-sha>`
- Tagged releases: `ghcr.io/<your-username>/pixi_jupyter_container:<git-tag>`

## Automated Dependency Updates

Automated updates are powered by [Renovate](https://github.com/apps/renovate). It keeps your Pixi environment and base images automatically up-to-date via pull requests.

## CI/CD Workflow

The GitHub Actions workflow handles:

- Automatic builds on push and pull requests.
- Automated container testing, including:
  - Docker healthcheck to ensure JupyterLab starts correctly.
  - Smoke tests verifying critical Python libraries (`NumPy`, `Pandas`, and `scikit-learn`) import successfully.
- Automatic generation and committing of `pixi.lock`.
- Security vulnerability scanning using [Trivy](https://github.com/aquasecurity/trivy).
- Publishing container images to GitHub Container Registry.

## Releases and Changelog

Releases are automatically drafted and changelogs generated through [Release Drafter](https://github.com/release-drafter/release-drafter). See the [GitHub Releases](../../releases) page for detailed changelogs and release notes.

## Advanced Usage

### Adding or Removing Packages

1. **Edit `pixi.toml`:** Add new dependencies under `[dependencies]` or `[pypi-dependencies]`.
2. **Rebuild the Container:**
   ```bash
   docker-compose build --no-cache
   docker-compose up
   ```
3. **Verify:** Make sure the new libraries import properly (e.g., `import your_package`).

### Changing Python Versions

To switch Python to another version (e.g., `3.11.x`), edit `pixi.toml`:

```toml
[dependencies]
python = "3.11.*"
```

Then rebuild and test as described above.

### Customizing JupyterLab

- **Themes:** Already includes JupyterThemes (Monokai). Change the theme inside JupyterLab’s settings or run:
  ```bash
  jt -t monokai
  ```
- **Extensions:** Add extensions to `pixi.toml` (if Conda-available) or to the `[pypi-dependencies]` section (if available via PyPI).

## Troubleshooting

### Jupyter Not Accessible  

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

- Delete existing `pixi.lock`, then regenerate it:
  ```bash
  pixi lock && pixi install
  ```

## Maintenance & Contribution

- **Dependency updates**: Renovate creates automatic PRs.
- **Testing**: Workflow tests changes automatically before merging.

Feel free to open issues or PRs to improve this stack.

## License

Distributed under the MIT License. See `LICENSE` for more information.
