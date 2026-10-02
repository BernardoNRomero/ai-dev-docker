#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}"

args=(docker compose -f docker-compose.yml --profile local --profile web --profile oracle)
if [[ -f .env.runtime ]]; then
  args=(docker compose --env-file .env.runtime -f docker-compose.yml --profile local --profile web --profile oracle)
fi

"${args[@]}" down "$@"
