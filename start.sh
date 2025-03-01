#!/bin/bash
set -e

source "${HOME}/pixi-activate.sh"

exec jupyter notebook \
  --no-browser \
  --no-mathjax \
  --ip=0.0.0.0 \
  --NotebookApp.token='' \
  --NotebookApp.password=''
