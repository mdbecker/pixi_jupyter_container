#!/bin/bash
set -e

exec "${HOME}/pixi-activate.sh" jupyter lab \
  --no-browser \
  --ip=0.0.0.0 \
  --IdentityProvider.token='' \
  --PasswordIdentityProvider.hashed_password='' \
  --PasswordIdentityProvider.password_required=False
