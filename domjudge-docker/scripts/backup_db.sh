#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Carga variables del .env si existe
if [[ -f "$PROJECT_DIR/.env" ]]; then
  # shellcheck source=/dev/null
  set -a && source "$PROJECT_DIR/.env" && set +a
fi

TS=$(date +%Y%m%d-%H%M%S)
mkdir -p "$PROJECT_DIR/backups"

docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T mariadb \
  mysqldump -u root -p"${MYSQL_ROOT_PASSWORD:?define MYSQL_ROOT_PASSWORD en .env}" domjudge \
  > "$PROJECT_DIR/backups/domjudge-${TS}.sql"

echo "Backup guardado en backups/domjudge-${TS}.sql"
