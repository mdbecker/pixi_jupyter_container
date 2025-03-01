# Stage 1: Download Pixi binary
FROM ubuntu:24.04 AS pixi-builder
ARG PIXI_VERSION=0.41.4
RUN apt-get update && apt-get install -y curl && \
    curl -Ls "https://github.com/prefix-dev/pixi/releases/download/v${PIXI_VERSION}/pixi-$(uname -m)-unknown-linux-musl" \
    -o /pixi && chmod +x /pixi

# Final Stage: Consolidated Environment Setup
FROM ubuntu:24.04 AS final
ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8 HOME="/home/${NB_USER}"

# Install all system dependencies and tools once (including Pixi lock)
RUN apt-get update && \
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

# Copy Pixi binary
COPY --from=pixi-builder /pixi /usr/local/bin/pixi

# Copy project files for Pixi
COPY pixi.toml ${HOME}/
WORKDIR ${HOME}

# Generate pixi.lock directly here (env-builder stage removed)
RUN pixi lock && \
    pixi install && \
    pixi shell-hook > ${HOME}/pixi-activate.sh && \
    echo 'exec "$@"' >> ${HOME}/pixi-activate.sh && \
    chmod +x ${HOME}/pixi-activate.sh && \
    rm -rf ~/.cache && \
    sudo apt-get purge -y --auto-remove build-essential && \
    sudo apt-get clean && \
    sudo rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy and set up startup scripts and permissions
COPY --chmod=0755 start.sh /usr/local/bin/start.sh

RUN fix-permissions /usr/local/bin/start.sh \
                    ${HOME}/pixi.toml \
                    ${HOME}/pixi.lock \
                    ${HOME}/work && \
    curl -fsSL https://raw.githubusercontent.com/jupyter/docker-stacks/main/images/base-notebook/docker_healthcheck.py \
        -o /etc/jupyter/docker_healthcheck.py && chmod +x /etc/jupyter/docker_healthcheck.py

# Switch to non-root user jovyan ONCE
USER ${NB_USER}

EXPOSE 8888

HEALTHCHECK --interval=10s --timeout=5s --start-period=10s --retries=3 \
    CMD /etc/jupyter/docker_healthcheck.py || exit 1

ENTRYPOINT ["tini", "-g", "--"]
WORKDIR ${HOME}/work
CMD ["start.sh"]
