#!/usr/bin/env bash
# MCP IntelliJ (scope user, stocké dans ~/.claude.json, non versionné) : déclaré s'il manque.
set -eu
command -v claude >/dev/null 2>&1 || { echo "claude absent : MCP intellij ignoré"; exit 0; }
if claude mcp get intellij >/dev/null 2>&1; then
  echo "MCP intellij : déjà déclaré"
else
  claude mcp add --scope user --transport sse intellij http://127.0.0.1:64342/sse
fi
