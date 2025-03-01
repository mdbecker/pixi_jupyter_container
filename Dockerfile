FROM quay.io/jupyter/docker-stacks-foundation:ubuntu-24.04 AS jupyter-base

FROM ubuntu:24.04 AS pixi-builder
ARG PIXI_VERSION=0.41.4
RUN apt-get update && apt-get install -y curl && \
    curl -Ls "https://github.com/prefix-dev/pixi/releases/download/v${PIXI_VERSION}/pixi-$(uname -m)-unknown-linux-musl" \
    -o /pixi && chmod +x /pixi

FROM ubuntu:24.04 AS env-builder
ARG NB_USER="jovyan"
ARG NB_UID="1000"
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y curl
COPY --from=pixi-builder /pixi /usr/local/bin/pixi
WORKDIR /tmp
COPY pixi.toml .
RUN pixi lock

FROM ubuntu:24.04
ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"

ENV DEBIAN_FRONTEND=noninteractive \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    HOME="/home/${NB_USER}"

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    tini sudo locales ca-certificates wget git \
    build-essential openssh-client imagemagick ffmpeg gifsicle \
    fonts-liberation pandoc run-one netbase && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=pixi-builder /pixi /usr/local/bin/pixi
COPY --from=jupyter-base /usr/local/bin/fix-permissions /usr/local/bin/fix-permissions
RUN chmod a+rx /usr/local/bin/fix-permissions

# Remove existing user with NB_UID if present, then add jovyan user
RUN if grep -q "${NB_UID}" /etc/passwd; then \
        userdel --remove $(id -un "${NB_UID}"); \
    fi && \
    useradd --no-log-init --create-home --shell /bin/bash --uid "${NB_UID}" "${NB_USER}" && \
    echo "${NB_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/notebook && \
    chmod g+w /etc/passwd

USER ${NB_USER}
WORKDIR ${HOME}

# Copy generated lockfile from env-builder stage
COPY --from=env-builder --chown=${NB_USER}:${NB_GID} /tmp/pixi.toml /tmp/pixi.lock ${HOME}/

# Install environment and setup pixi activation script
RUN pixi install && \
    pixi shell-hook > ${HOME}/pixi-activate.sh && \
    chmod +x ${HOME}/pixi-activate.sh

# Install Jupyter extensions in a single shell activation step
RUN bash -c "source ${HOME}/pixi-activate.sh && \
    jupyter contrib nbextension install --sys-prefix && \
    jupyter nbextension enable table_beautifier/main --sys-prefix && \
    jupyter nbextension enable execute_time/ExecuteTime --sys-prefix && \
    jupyter nbextension enable code_prettify/code_prettify --sys-prefix && \
    jupyter nbextension enable execution_dependencies/execution_dependencies --sys-prefix && \
    jupyter nbextension enable python-markdown/main --sys-prefix && \
    jupyter nbextension enable skip-traceback/main --sys-prefix && \
    jt -t monokai -f anonymous -fs 11 -nf ptsans -nfs 11 -cursw 2 -cursc r -cellw 99% -lineh 110 -T -N -ofs 11"

USER root
RUN fix-permissions "${HOME}"

COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh && fix-permissions /usr/local/bin/start.sh

EXPOSE 8888
ENTRYPOINT ["tini", "-g", "--"]
USER ${NB_USER}
CMD ["start.sh"]
