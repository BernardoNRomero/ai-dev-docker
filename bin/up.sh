#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}"

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Se creo .env desde .env.example. Revisalo si vas a usar API u Oracle."
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

mem_kb="$(awk '/MemTotal:/ {print $2}' /proc/meminfo)"
avail_kb="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)"
mem_gb="$((mem_kb / 1024 / 1024))"
avail_gb="$((avail_kb / 1024 / 1024))"
host_cpus="$(nproc)"

backend="${AI_BACKEND:-ollama}"
enable_web="${ENABLE_WEBUI:-}"
enable_oracle=0
print_only=0

for arg in "$@"; do
  case "${arg}" in
    --api) backend="openai" ;;
    --web) enable_web=1 ;;
    --no-web) enable_web=0 ;;
    --oracle) enable_oracle=1 ;;
    --print) print_only=1 ;;
    -h|--help)
      cat << 'EOF'
Uso: ./bin/up.sh [--api] [--web|--no-web] [--oracle]

Sin flags lee la RAM de esta PC y elige modelo, contexto y limites.
La imagen no cambia al pasar de 8 GB a 16 GB o mas: solo vuelve a correr este script.
EOF
      exit 0
      ;;
    *)
      echo "Opcion desconocida: ${arg}" >&2
      exit 1
      ;;
  esac
done

if (( mem_gb < 12 )); then
  profile="8gb"
  : "${AI_MODEL:=qwen2.5-coder:3b}"
  : "${OLLAMA_MEM_LIMIT:=3800m}"
  : "${OLLAMA_CPUS:=6}"
  : "${OLLAMA_NUM_CTX:=4096}"
  : "${OLLAMA_NUM_PARALLEL:=1}"
  : "${OLLAMA_KEEP_ALIVE:=5m}"
  : "${OLLAMA_KV_CACHE_TYPE:=q8_0}"
  : "${WORKSTATION_MEM_LIMIT:=1400m}"
  : "${WORKSTATION_CPUS:=2}"
  : "${AIDER_EDIT_FORMAT:=whole}"
  : "${AIDER_MAP_TOKENS:=0}"
  : "${WEBUI_MEM_LIMIT:=768m}"
  : "${ORACLE_MEM_LIMIT:=2g}"
  default_web=0
  need_avail_gb=4
elif (( mem_gb < 24 )); then
  profile="16gb"
  : "${AI_MODEL:=qwen2.5-coder:7b}"
  : "${OLLAMA_MEM_LIMIT:=8g}"
  : "${OLLAMA_CPUS:=8}"
  : "${OLLAMA_NUM_CTX:=8192}"
  : "${OLLAMA_NUM_PARALLEL:=1}"
  : "${OLLAMA_KEEP_ALIVE:=20m}"
  : "${OLLAMA_KV_CACHE_TYPE:=q8_0}"
  : "${WORKSTATION_MEM_LIMIT:=2g}"
  : "${WORKSTATION_CPUS:=3}"
  : "${AIDER_EDIT_FORMAT:=diff}"
  : "${AIDER_MAP_TOKENS:=1024}"
  : "${WEBUI_MEM_LIMIT:=1g}"
  : "${ORACLE_MEM_LIMIT:=2g}"
  default_web=1
  need_avail_gb=7
elif (( mem_gb < 40 )); then
  profile="24gb"
  : "${AI_MODEL:=qwen2.5-coder:14b}"
  : "${OLLAMA_MEM_LIMIT:=14g}"
  : "${OLLAMA_CPUS:=12}"
  : "${OLLAMA_NUM_CTX:=16384}"
  : "${OLLAMA_NUM_PARALLEL:=1}"
  : "${OLLAMA_KEEP_ALIVE:=30m}"
  : "${OLLAMA_KV_CACHE_TYPE:=f16}"
  : "${WORKSTATION_MEM_LIMIT:=3g}"
  : "${WORKSTATION_CPUS:=4}"
  : "${AIDER_EDIT_FORMAT:=diff}"
  : "${AIDER_MAP_TOKENS:=2048}"
  : "${WEBUI_MEM_LIMIT:=1536m}"
  : "${ORACLE_MEM_LIMIT:=3g}"
  default_web=1
  need_avail_gb=12
else
  profile="32gb"
  : "${AI_MODEL:=qwen3-coder:30b}"
  : "${OLLAMA_MEM_LIMIT:=22g}"
  : "${OLLAMA_CPUS:=16}"
  : "${OLLAMA_NUM_CTX:=32768}"
  : "${OLLAMA_NUM_PARALLEL:=1}"
  : "${OLLAMA_KEEP_ALIVE:=30m}"
  : "${OLLAMA_KV_CACHE_TYPE:=f16}"
  : "${WORKSTATION_MEM_LIMIT:=4g}"
  : "${WORKSTATION_CPUS:=4}"
  : "${AIDER_EDIT_FORMAT:=diff}"
  : "${AIDER_MAP_TOKENS:=4096}"
  : "${WEBUI_MEM_LIMIT:=2g}"
  : "${ORACLE_MEM_LIMIT:=4g}"
  default_web=1
  need_avail_gb=20
fi

if [[ -z "${enable_web}" ]]; then
  enable_web="${default_web}"
fi

if (( OLLAMA_CPUS > host_cpus )); then
  OLLAMA_CPUS="${host_cpus}"
fi
if (( WORKSTATION_CPUS > host_cpus )); then
  WORKSTATION_CPUS="${host_cpus}"
fi

if (( enable_oracle == 1 && mem_gb < 12 )) && [[ "${backend}" == "ollama" ]]; then
  echo "Oracle Free pide unos 2 GB extra. En 8 GB no entra junto con el modelo local." >&2
  echo "Opciones: ./bin/up.sh --api --oracle, o una PC con 16 GB o mas." >&2
  exit 1
fi

if (( enable_oracle == 1 )); then
  if [[ -z "${ORACLE_PASSWORD:-}" || "${ORACLE_PASSWORD}" == cambia-esta-clave* ]]; then
    echo "Defini ORACLE_PASSWORD en .env antes de usar --oracle." >&2
    exit 1
  fi
  if [[ -z "${ORACLE_APP_PASSWORD:-}" || "${ORACLE_APP_PASSWORD}" == cambia-esta-clave* ]]; then
    echo "Defini ORACLE_APP_PASSWORD en .env antes de usar --oracle." >&2
    exit 1
  fi
fi

if [[ "${backend}" == "openai" ]]; then
  if [[ -z "${OPENAI_API_KEY:-}" && -z "${OPENAI_API_BASE:-}" ]]; then
    echo "Para --api defini OPENAI_API_KEY o OPENAI_API_BASE en .env." >&2
    exit 1
  fi
  if [[ -z "${AI_MODEL:-}" || "${AI_MODEL}" == qwen* ]]; then
    AI_MODEL="${OPENAI_MODEL:-gpt-4.1}"
  fi
  AIDER_EDIT_FORMAT="diff"
  AIDER_MAP_TOKENS="2048"
fi

if [[ "${backend}" == "ollama" && "${avail_gb}" -lt "${need_avail_gb}" ]]; then
  echo "AVISO: hay unos ${avail_gb} GB libres y el perfil ${profile} conviene con ~${need_avail_gb} GB libres."
  echo "Cerra navegador u otras apps. Si la PC se queda corta: AI_MODEL=qwen2.5-coder:1.5b ./bin/up.sh"
  echo "O usa una API, que casi no consume RAM: ./bin/up.sh --api"
fi

cat > .env.runtime << EOF
AI_BACKEND=${backend}
AI_MODEL=${AI_MODEL}
AI_PROFILE=${profile}
AIDER_EDIT_FORMAT=${AIDER_EDIT_FORMAT}
AIDER_MAP_TOKENS=${AIDER_MAP_TOKENS}
OLLAMA_MEM_LIMIT=${OLLAMA_MEM_LIMIT}
OLLAMA_CPUS=${OLLAMA_CPUS}
OLLAMA_NUM_CTX=${OLLAMA_NUM_CTX}
OLLAMA_NUM_PARALLEL=${OLLAMA_NUM_PARALLEL}
OLLAMA_KEEP_ALIVE=${OLLAMA_KEEP_ALIVE}
OLLAMA_KV_CACHE_TYPE=${OLLAMA_KV_CACHE_TYPE}
OLLAMA_PORT=${OLLAMA_PORT:-11434}
WORKSTATION_MEM_LIMIT=${WORKSTATION_MEM_LIMIT}
WORKSTATION_CPUS=${WORKSTATION_CPUS}
WEBUI_MEM_LIMIT=${WEBUI_MEM_LIMIT}
WEBUI_PORT=${WEBUI_PORT:-3000}
WEB_PORT=${WEB_PORT:-8080}
ORACLE_MEM_LIMIT=${ORACLE_MEM_LIMIT}
ORACLE_PORT=${ORACLE_PORT:-1521}
ORACLE_PASSWORD=${ORACLE_PASSWORD:-}
ORACLE_USER=${ORACLE_USER:-dev}
ORACLE_APP_PASSWORD=${ORACLE_APP_PASSWORD:-}
ORACLE_DSN=${ORACLE_DSN:-oracle:1521/FREEPDB1}
OPENAI_API_BASE=${OPENAI_API_BASE:-}
OPENAI_API_KEY=${OPENAI_API_KEY:-}
SSH_DIR=${SSH_DIR:-./ssh}
ENABLE_WEBUI=${enable_web}
ENABLE_ORACLE=${enable_oracle}
EOF

compose=(docker compose --env-file .env.runtime -f docker-compose.yml)
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1 && docker info 2>/dev/null | grep -qi nvidia; then
  compose+=(-f docker-compose.gpu.yml)
  echo "GPU NVIDIA detectada. Ollama va a usarla si el toolkit esta instalado."
fi

profiles=()
if [[ "${backend}" == "ollama" ]]; then
  profiles+=(--profile local)
fi
if [[ "${enable_web}" == "1" && "${backend}" == "ollama" ]]; then
  profiles+=(--profile web)
fi
if (( enable_oracle == 1 )); then
  profiles+=(--profile oracle)
fi

echo "Perfil ${profile} (${mem_gb} GB detectados) | backend ${backend} | modelo ${AI_MODEL}"
echo "Tope Ollama: ${OLLAMA_MEM_LIMIT} | contexto: ${OLLAMA_NUM_CTX} | edicion: ${AIDER_EDIT_FORMAT}"

if (( print_only == 1 )); then
  echo "Perfil escrito en .env.runtime. No se levantaron contenedores."
  exit 0
fi

"${compose[@]}" "${profiles[@]}" up -d --build workstation

if [[ "${backend}" == "ollama" ]]; then
  "${compose[@]}" "${profiles[@]}" up -d ollama
  "${compose[@]}" "${profiles[@]}" run --rm model-pull
fi

"${compose[@]}" "${profiles[@]}" up -d

echo
echo "Listo."
echo "  Preview PHP:  http://127.0.0.1:${WEB_PORT:-8080}"
echo "  Agente:       ./bin/ai.sh \"arma un formulario de contacto en PHP\""
echo "  Shell:        ./bin/shell.sh"
if [[ "${enable_web}" == "1" && "${backend}" == "ollama" ]]; then
  echo "  Chat web:     http://127.0.0.1:${WEBUI_PORT:-3000}"
fi
if (( enable_oracle == 1 )); then
  echo "  Oracle:       ${ORACLE_DSN:-oracle:1521/FREEPDB1} (puede tardar varios minutos en el primer arranque)"
fi
