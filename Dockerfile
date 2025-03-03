# syntax=docker/dockerfile:1.4

# Stage 1: Download Latest Pixi Binary
FROM ubuntu:latest AS pixi-builder
# Install curl and jq for querying the GitHub API
RUN apt-get update && apt-get install -y curl jq
# Query GitHub API for the latest Pixi release tag, then download and extract the binary
RUN latest=$(curl -s https://api.github.com/repos/prefix-dev/pixi/releases/latest | jq -r .tag_name) && \
    echo "Latest Pixi release: ${latest}" && \
    curl -Ls "https://github.com/prefix-dev/pixi/releases/download/${latest}/pixi-$(uname -m)-unknown-linux-musl.tar.gz" -o /pixi.tar.gz && \
    tar -xzf /pixi.tar.gz -C / && \
    chmod +x /pixi && \
    rm /pixi.tar.gz

# Final Stage: Consolidated Environment Setup
FROM ubuntu:latest AS final
ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"

# Set environment variables for the notebook user
ENV NB_USER=${NB_USER} \
    NB_UID=${NB_UID} \
    NB_GID=${NB_GID} \
    DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    HOME="/home/${NB_USER}"

RUN --mount=type=cache,id=apt-cache-final,target=/var/cache/apt \
    --mount=type=cache,id=apt-lists-final,target=/var/lib/apt/lists \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        tini sudo locales ca-certificates wget git openssh-client \
        imagemagick ffmpeg gifsicle fonts-liberation pandoc run-one netbase \
        curl build-essential && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen && \
    curl -fsSL https://raw.githubusercontent.com/jupyter/docker-stacks/refs/heads/main/images/docker-stacks-foundation/fix-permissions \
        -o /usr/local/bin/fix-permissions && chmod +x /usr/local/bin/fix-permissions && \
    if grep -q "${NB_UID}" /etc/passwd; then userdel --remove $(id -un "${NB_UID}"); fi && \
    useradd --no-log-init --create-home --shell /bin/bash --uid "${NB_UID}" "${NB_USER}" && \
    echo "${NB_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/notebook && \
    chmod g+w /etc/passwd && \
    mkdir -p ${HOME}/work /etc/jupyter && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy the Pixi binary from the builder stage
COPY --from=pixi-builder /pixi /usr/local/bin/pixi
COPY pixi.toml ${HOME}/
WORKDIR ${HOME}

# Properly create pixi-activate.sh by including the shell hook script correctly
RUN pixi lock && \
    pixi install && \
    echo '#!/usr/bin/env bash' > ${HOME}/pixi-activate.sh && \
    pixi shell-hook --change-ps1=false >> ${HOME}/pixi-activate.sh && \
    echo 'exec "$@"' >> ${HOME}/pixi-activate.sh && \
    chmod +x ${HOME}/pixi-activate.sh && \
    rm -rf ~/.cache && \
    apt-get purge -y --auto-remove build-essential && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# PURPOSEFULLY PRE-BUILD JUPYTER CACHE
RUN ${HOME}/pixi-activate.sh jupyter --version && \
    ${HOME}/pixi-activate.sh jupyter lab --generate-config

# Set the default theme to dark mode by creating the user settings file
RUN mkdir -p ${HOME}/.jupyter/lab/user-settings/@jupyterlab/apputils-extension/ && \
    echo '{ "theme": "JupyterLab Dark" }' > ${HOME}/.jupyter/lab/user-settings/@jupyterlab/apputils-extension/themes.jupyterlab-settings

COPY --chmod=0755 start.sh /usr/local/bin/start.sh

RUN fix-permissions /usr/local/bin/start.sh \
                    ${HOME}/pixi.toml \
                    ${HOME}/pixi.lock \
                    ${HOME}/pixi-activate.sh \
                    ${HOME}/work && \
    curl -fsSL https://raw.githubusercontent.com/jupyter/docker-stacks/main/images/base-notebook/docker_healthcheck.py \
        -o /etc/jupyter/docker_healthcheck.py && chmod +x /etc/jupyter/docker_healthcheck.py

# Recursively set ownership of the home directory to NB_USER (jovyan)
RUN chown -R ${NB_USER}:${NB_USER} ${HOME}

USER ${NB_USER}

EXPOSE 8888

# Updated healthcheck with increased start-period for stability during startup
HEALTHCHECK --interval=10s --timeout=5s --start-period=45s --retries=3 \
    CMD ${HOME}/pixi-activate.sh /etc/jupyter/docker_healthcheck.py || exit 1

ENTRYPOINT ["tini", "-g", "--"]
WORKDIR ${HOME}/work
CMD ["start.sh"]
