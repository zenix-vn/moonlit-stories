#!/usr/bin/env bash
set -euo pipefail

# Moonlit Stories deployment script
# Modes:
# 1) local  -> run directly on server (source already present)
# 2) remote -> run from local machine, rsync to server then deploy via ssh

MODE="${1:-local}"

# Shared defaults
APP_NAME="moonlit_stories"
REMOTE_APP_DIR="${REMOTE_APP_DIR:-/opt/moonlit_stories}"
DEFAULT_SSH_HOST="42.96.17.167"
COMPOSE_FILE_REL="backend/docker-compose.prod.yml"
ENV_FILE_REL="backend/.env.prod"
BACKEND_SERVICE="moonlit-backend-prod"
POSTGRES_SERVICE="moonlit-postgres-prod"

log() {
  printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

run_migration() {
  local repo_root="$1"
  local compose_file="$repo_root/$COMPOSE_FILE_REL"
  local env_file="$repo_root/$ENV_FILE_REL"
  local schema_file="$repo_root/backend/migrations/schema.sql"

  if [[ ! -f "$schema_file" ]]; then
    echo "Schema file not found: $schema_file" >&2
    exit 1
  fi

  local compose_cmd=(docker compose -f "$compose_file")
  if [[ -f "$env_file" ]]; then
    compose_cmd+=(--env-file "$env_file")
  fi

  log "Running DB migration from backend/migrations/schema.sql"
  "${compose_cmd[@]}" exec -T postgres sh -lc 'psql -U "${DB_USER:-postgres}" -d "${DB_NAME:-moonlit_stories}"' < "$schema_file"
}

run_local_deploy() {
  require_cmd docker

  local repo_root
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local compose_file="$repo_root/$COMPOSE_FILE_REL"
  local env_file="$repo_root/$ENV_FILE_REL"

  if [[ ! -f "$compose_file" ]]; then
    echo "Compose file not found: $compose_file" >&2
    exit 1
  fi

  local compose_cmd=(docker compose -f "$compose_file")
  if [[ -f "$env_file" ]]; then
    compose_cmd+=(--env-file "$env_file")
    log "Using env file: $env_file"
  else
    log "No env file at $env_file, using values from compose/default env"
  fi

  log "Pulling base images"
  "${compose_cmd[@]}" pull postgres redis || true

  log "Building and starting backend + admin + infra"
  "${compose_cmd[@]}" up -d --build postgres redis backend admin

  run_migration "$repo_root"

  log "Service status"
  "${compose_cmd[@]}" ps

  log "Deployment completed"
}

run_remote_deploy() {
  require_cmd rsync
  require_cmd ssh

  local ssh_host="${SSH_HOST:-$DEFAULT_SSH_HOST}"
  local ssh_user="${SSH_USER:-}"
  local ssh_port="${SSH_PORT:-}"

  if [[ -z "$ssh_user" || -z "$ssh_port" ]]; then
    local resolved
    resolved="$(ssh -G "$ssh_host" 2>/dev/null || true)"
    if [[ -z "$ssh_user" ]]; then
      ssh_user="$(printf '%s\n' "$resolved" | awk '/^user /{print $2; exit}')"
    fi
    if [[ -z "$ssh_port" ]]; then
      ssh_port="$(printf '%s\n' "$resolved" | awk '/^port /{print $2; exit}')"
    fi
  fi

  ssh_port="${ssh_port:-22}"

  if [[ -z "$ssh_host" || -z "$ssh_user" ]]; then
    cat >&2 <<USAGE
For remote mode, set these environment variables:
  SSH_HOST=<server ip or domain>
  SSH_USER=<ssh user>
Optional:
  SSH_PORT=22
  REMOTE_APP_DIR=/opt/moonlit_stories

Defaults in this script:
  SSH_HOST=$DEFAULT_SSH_HOST
  SSH_USER/SSH_PORT are auto-detected from ~/.ssh/config when available
USAGE
    exit 1
  fi

  log "Remote target: ${ssh_user}@${ssh_host}:${ssh_port}"

  local repo_root
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

  log "Creating remote directory: $REMOTE_APP_DIR"
  ssh -p "$ssh_port" "$ssh_user@$ssh_host" "mkdir -p '$REMOTE_APP_DIR'"

  log "Syncing source code to server"
  rsync -az --delete \
    --exclude '.git' \
    --exclude 'node_modules' \
    --exclude '.next' \
    --exclude 'dist' \
    --exclude '.DS_Store' \
    -e "ssh -p $ssh_port" \
    "$repo_root/" "$ssh_user@$ssh_host:$REMOTE_APP_DIR/"

  log "Running deploy on server"
  ssh -p "$ssh_port" "$ssh_user@$ssh_host" "cd '$REMOTE_APP_DIR' && bash scripts/deploy.sh local"

  log "Remote deployment completed"
}

case "$MODE" in
  local)
    run_local_deploy
    ;;
  remote)
    run_remote_deploy
    ;;
  *)
    echo "Usage: $0 [local|remote]"
    exit 1
    ;;
esac
