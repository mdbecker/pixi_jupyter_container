#!/bin/bash
set -e

# === DEBUGGING OUTPUT ===
echo "DEBUG: Running start.sh" 1>&2
echo "DEBUG: PATH=$PATH" 1>&2
echo "DEBUG: PYTHON=$(which python)" 1>&2
echo "DEBUG: PYTHON_VERSION=$(python --version 2>&1)" 1>&2
echo "DEBUG: JUPYTER=$(which jupyter)" 1>&2
echo "DEBUG: JUPYTER_VERSION=$(jupyter --version 2>&1)" 1>&2

exec "${HOME}/pixi-activate.sh" jupyter lab \
  --no-browser \
  --ip=0.0.0.0 \
  --ServerApp.token='' \
  --ServerApp.password=''
