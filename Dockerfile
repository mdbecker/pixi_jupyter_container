# Stage 1: Download the Pixi binary
FROM ubuntu:24.04 AS pixi-builder
ARG PIXI_VERSION=0.41.4
RUN apt-get update && apt-get install -y curl && \
    curl -Ls "https://github.com/prefix-dev/pixi/releases/download/v${PIXI_VERSION}/pixi-$(uname -m)-unknown-linux-musl" \
    -o /pixi && chmod +x /pixi

# Stage 2: Generate pixi.lock
FROM ubuntu:24.04 AS env-builder
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
WORKDIR /tmp

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      tini sudo locales ca-certificates wget git build-essential openssh-client \
      imagemagick ffmpeg gifsicle fonts-liberation pandoc run-one netbase && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=pixi-builder /pixi /usr/local/bin/pixi

COPY pixi.toml .
RUN pixi lock

# Stage 3 (Final): Install environment directly in the final image
FROM ubuntu:24.04 AS final
ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8 HOME="/home/${NB_USER}"

# Consolidated RUN commands for efficiency
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      tini sudo locales ca-certificates fonts-liberation pandoc build-essential curl && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen && \
    curl -fsSL https://raw.githubusercontent.com/jupyter/docker-stacks/refs/heads/main/images/docker-stacks-foundation/fix-permissions \
        -o /usr/local/bin/fix-permissions && chmod a+rx /usr/local/bin/fix-permissions && \
    if grep -q "${NB_UID}" /etc/passwd; then userdel --remove $(id -un "${NB_UID}"); fi && \
    useradd --no-log-init --create-home --shell /bin/bash --uid "${NB_UID}" "${NB_USER}" && \
    echo "${NB_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/notebook && \
    chmod g+w /etc/passwd && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=pixi-builder /pixi /usr/local/bin/pixi

USER ${NB_USER}
WORKDIR ${HOME}

COPY --from=env-builder --chown=${NB_USER}:${NB_GID} /tmp/pixi.toml ${HOME}/
COPY --from=env-builder --chown=${NB_USER}:${NB_GID} /tmp/pixi.lock ${HOME}/

RUN pixi install && \
    pixi shell-hook > ${HOME}/pixi-activate.sh && \
    echo 'exec "$@"' >> ${HOME}/pixi-activate.sh && \
    chmod +x ${HOME}/pixi-activate.sh && \
    rm -rf ~/.cache && \
    sudo apt-get purge -y --auto-remove build-essential && \
    sudo apt-get clean && \
    sudo rm -rf /var/lib/apt/lists/* && \
    sudo rm -rf /tmp/* /var/tmp/*

USER root
COPY --chmod=0755 start.sh /usr/local/bin/start.sh

RUN mkdir -p ${HOME}/work && \
    fix-permissions /usr/local/bin/start.sh && \
    fix-permissions ${HOME}/pixi.toml ${HOME}/pixi.lock ${HOME}/pixi-activate.sh ${HOME}/work && \
    mkdir -p /etc/jupyter && \
    curl -fsSL https://raw.githubusercontent.com/jupyter/docker-stacks/refs/heads/main/images/base-notebook/docker_healthcheck.py \
        -o /etc/jupyter/docker_healthcheck.py && chmod +x /etc/jupyter/docker_healthcheck.py

EXPOSE 8888

HEALTHCHECK --interval=10s --timeout=5s --start-period=10s --retries=3 \
    CMD /etc/jupyter/docker_healthcheck.py || exit 1

ENTRYPOINT ["tini", "-g", "--"]
WORKDIR ${HOME}/work
USER ${NB_USER}
CMD ["start.sh"]
