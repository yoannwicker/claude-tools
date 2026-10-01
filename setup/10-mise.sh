#!/usr/bin/env bash
# mise : installe mise si absent, puis les outils globaux de ~/.config/mise/config.toml.
set -eu
if ! command -v mise >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/mise" ]; then
  curl -fsSL https://mise.run | sh
fi
mise=$(command -v mise || echo "$HOME/.local/bin/mise")
"$mise" install --yes
"$mise" ls --global
