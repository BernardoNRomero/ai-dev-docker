#!/bin/sh
set -eu

backend="${AI_BACKEND:-ollama}"
model="${AI_MODEL:-qwen2.5-coder:3b}"
edit_format="${AIDER_EDIT_FORMAT:-whole}"
map_tokens="${AIDER_MAP_TOKENS:-0}"
ollama_base="${OLLAMA_API_BASE:-http://ollama:11434}"

export OLLAMA_API_BASE="${ollama_base}"

if [ "${backend}" = "ollama" ]; then
  aider_model="ollama_chat/${model}"
  api_base="${ollama_base}"
  api_key="ollama"
else
  aider_model="openai/${model}"
  api_base="${OPENAI_API_BASE:-https://api.openai.com/v1}"
  api_key="${OPENAI_API_KEY:-}"
fi

cat > /root/.aider.conf.yml << EOF
model: ${aider_model}
openai-api-base: ${api_base}
openai-api-key: ${api_key}
edit-format: ${edit_format}
map-tokens: ${map_tokens}
auto-commits: false
dirty-commits: false
attribute-author: false
attribute-committer: false
stream: true
dark-mode: true
pretty: true
read:
  - /opt/ai/CODING.md
EOF

git config --global --add safe.directory /workspace || true

echo "Backend: ${backend}"
echo "Modelo: ${model}"
echo "Formato de edicion: ${edit_format}"
echo "Codigo: /workspace"
echo "Agente: ai \"pedido en espanol\""

if ! apache2ctl start; then
  echo "Apache no arranco. Revisa el log del contenedor." >&2
fi

exec "$@"
