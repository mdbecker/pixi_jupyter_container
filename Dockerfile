# Stage 1: Get fix-permissions from official Jupyter stack
FROM quay.io/jupyter/docker-stacks-foundation:ubuntu-24.04 AS jupyter-base

# Stage 2: Download the Pixi binary
FROM ubuntu:24.04 AS pixi-builder
ARG PIXI_VERSION=0.41.4
RUN apt-get update && apt-get install -y curl && \
    curl -Ls "https://github.com/prefix-dev/pixi/releases/download/v${PIXI_VERSION}/pixi-$(uname -m)-unknown-linux-musl" \
    -o /pixi && chmod +x /pixi

# Stage 3: Generate pixi.lock
FROM ubuntu:24.04 AS env-builder
ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8 HOME="/home/${NB_USER}"

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    tini sudo locales ca-certificates wget git build-essential openssh-client imagemagick ffmpeg gifsicle fonts-liberation pandoc run-one netbase && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=pixi-builder /pixi /usr/local/bin/pixi

RUN if grep -q "${NB_UID}" /etc/passwd; then \
        userdel --remove $(id -un "${NB_UID}"); \
    fi && \
    useradd --no-log-init --create-home --shell /bin/bash --uid "${NB_UID}" "${NB_USER}" && \
    echo "${NB_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/notebook && \
    chmod g+w /etc/passwd

USER ${NB_USER}
WORKDIR ${HOME}

COPY --chown=${NB_USER}:${NB_GID} pixi.toml ${HOME}/
RUN pixi lock

# Stage 4 (Final): Install environment directly in the final image
FROM ubuntu:24.04 AS final
ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8 HOME="/home/${NB_USER}"

# Install runtime dependencies (build-essential temporarily)
RUN apt-get update && apt-get install -y --no-install-recommends \
    tini sudo locales ca-certificates fonts-liberation pandoc build-essential && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen

COPY --from=jupyter-base /usr/local/bin/fix-permissions /usr/local/bin/fix-permissions
RUN chmod a+rx /usr/local/bin/fix-permissions

COPY --from=pixi-builder /pixi /usr/local/bin/pixi

RUN if grep -q "${NB_UID}" /etc/passwd; then \
        userdel --remove $(id -un "${NB_UID}"); \
    fi && \
    useradd --no-log-init --create-home --shell /bin/bash --uid "${NB_UID}" "${NB_USER}" && \
    echo "${NB_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/notebook && \
    chmod g+w /etc/passwd

USER ${NB_USER}
WORKDIR ${HOME}

COPY --from=env-builder --chown=${NB_USER}:${NB_GID} ${HOME}/pixi.toml ${HOME}/
COPY --from=env-builder --chown=${NB_USER}:${NB_GID} ${HOME}/pixi.lock ${HOME}/

# Install Pixi environment and cleanup cache/build-essential
RUN pixi install && \
    pixi shell-hook > ${HOME}/pixi-activate.sh && \
    echo 'exec "$@"' >> ${HOME}/pixi-activate.sh && \
    chmod +x ${HOME}/pixi-activate.sh && \
    rm -rf ~/.cache && \
    sudo apt-get purge -y --auto-remove build-essential && \
    sudo apt-get clean && \
    sudo rm -rf /var/lib/apt/lists/*

# (Optional) Add debug script
RUN mkdir -p ${HOME}/debug && \
    echo '#!/bin/bash' > ${HOME}/debug/check-env.sh && \
    echo 'echo "PATH before activate: $PATH"' >> ${HOME}/debug/check-env.sh && \
    echo 'source ${HOME}/pixi-activate.sh' >> ${HOME}/debug/check-env.sh && \
    echo 'echo "PATH after activate: $PATH"' >> ${HOME}/debug/check-env.sh && \
    echo 'pixi list' >> ${HOME}/debug/check-env.sh && \
    echo 'which python || echo "Python not found"' >> ${HOME}/debug/check-env.sh && \
    echo 'which jupyter || echo "Jupyter not found"' >> ${HOME}/debug/check-env.sh && \
    chmod +x ${HOME}/debug/check-env.sh

USER root
COPY start.sh /usr/local/bin/start.sh

# Explicitly create the work directory first
RUN mkdir -p ${HOME}/work && \
    chmod +x /usr/local/bin/start.sh && \
    fix-permissions /usr/local/bin/start.sh && \
    fix-permissions ${HOME}/pixi.toml ${HOME}/pixi.lock ${HOME}/pixi-activate.sh ${HOME}/work

EXPOSE 8888
ENTRYPOINT ["tini", "-g", "--"]
WORKDIR ${HOME}/work
USER ${NB_USER}
CMD ["start.sh"]
