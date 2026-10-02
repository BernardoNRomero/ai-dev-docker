#!/bin/sh
set -eu

cd /workspace

if [ ! -d .git ]; then
  git init -q
  git config user.email "dev@local"
  git config user.name "Dev"
fi

if [ "${AI_BACKEND:-ollama}" = "ollama" ]; then
  base="${OLLAMA_API_BASE:-http://ollama:11434}"
  if ! curl -fsS "${base}/api/tags" >/dev/null; then
    echo "Ollama no responde en ${base}." >&2
    echo "En el host ejecuta ./bin/up.sh y espera a que termine la descarga del modelo." >&2
    exit 1
  fi
fi

if [ "$#" -eq 0 ]; then
  exec aider
fi

exec aider --message "$*"
