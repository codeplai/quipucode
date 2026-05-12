#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

SQL_FILE="${1:-}"
if [[ -z "$SQL_FILE" ]]; then
  echo "Uso: $0 <archivo.sql>" >&2
  exit 1
fi

if [[ ! -f "$SQL_FILE" ]]; then
  echo "ERROR: No se encontró el archivo '$SQL_FILE'" >&2
  exit 1
fi

# Carga variables del .env si existe
if [[ -f "$PROJECT_DIR/.env" ]]; then
  set -a && source "$PROJECT_DIR/.env" && set +a
fi

echo "Restaurando '$SQL_FILE' en la base de datos domjudge..."
docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T mariadb \
  mysql -u root -p"${MYSQL_ROOT_PASSWORD:?define MYSQL_ROOT_PASSWORD en .env}" domjudge \
  < "$SQL_FILE"

echo "Restauración completada."
