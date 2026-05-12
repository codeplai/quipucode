#!/usr/bin/env bash
# Añade el lenguaje Go a DOMjudge (compatible con DOMjudge 8.3+).
# Uso: bash scripts/add_go_language.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."
source .env

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
info() { echo -e "${YELLOW}→${NC} $*"; }

db() { docker compose exec -T mariadb mariadb -u root -p"${MYSQL_ROOT_PASSWORD}" domjudge -e "$1"; }

echo ""
echo "╔══════════════════════════════════════╗"
echo "║  QuipuCode — Añadir lenguaje Go      ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ── Si Go ya existe, solo habilitarlo ─────────────────────
GO_COUNT=$(db "SELECT COUNT(*) FROM language WHERE langid='go';" | tail -1 | tr -d '[:space:]')
if [ "$GO_COUNT" = "1" ]; then
  info "Go ya existe — habilitando..."
  db "UPDATE language SET allow_submit=1, allow_judge=1 WHERE langid='go';"
  ok "Go habilitado. Ve a https://quipucode.lat/jury/languages y ajusta el memory limit a 512000 KB."
  docker compose restart domserver
  exit 0
fi

info "Creando ejecutable y lenguaje Go (DOMjudge 8.3+ schema)..."

# ── Build script ──────────────────────────────────────────
cat > /tmp/go_build.sh << 'BUILDSCRIPT'
#!/bin/sh
DEST="$1"; shift
MEMLIMIT="$1"; shift
TIMELIMIT="$1"; shift
ENTRY_POINT="$1"; shift
export GOPATH=/tmp/gopath
export GOCACHE=/tmp/gocache
export GOFLAGS=""
export GONOSUMDB="*"
exec /usr/local/go/bin/go build -o "$DEST" "$@"
BUILDSCRIPT

HEX=$(xxd -p /tmp/go_build.sh | tr -d '\n')
MD5=$(md5sum /tmp/go_build.sh | cut -d' ' -f1)
info "Script: $((${#HEX}/2)) bytes — MD5: ${MD5}"

# ── SQL ───────────────────────────────────────────────────
SQL_FILE="/tmp/add_go_$(date +%s).sql"
cat > "${SQL_FILE}" << SQLEOF
INSERT INTO immutable_executable (userid, hash) VALUES (NULL, '${MD5}');
SET @imm_id = LAST_INSERT_ID();
INSERT INTO executable_file
  (immutable_execid, filename, ranknumber, file_content, hash, is_executable)
  VALUES (@imm_id, 'build', 1, 0x${HEX}, '${MD5}', 1);
INSERT IGNORE INTO executable (execid, type, description, immutable_execid)
  VALUES ('go', 'compile', 'go', @imm_id);
INSERT IGNORE INTO language
  (langid, externalid, name, extensions, require_entry_point,
   entry_point_description, allow_submit, allow_judge, time_factor,
   compile_script, filter_compiler_files)
  VALUES ('go', 'go', 'Go', '["go"]', 0, NULL, 1, 1, 1, 'go', 1);
SQLEOF

docker compose exec -T mariadb mariadb -u root -p"${MYSQL_ROOT_PASSWORD}" domjudge \
  < "${SQL_FILE}"
rm -f "${SQL_FILE}"

# ── Verificar ─────────────────────────────────────────────
LANG=$(db "SELECT langid, name FROM language WHERE langid='go';" | tail -1)
EXEC=$(db "SELECT execid, type FROM executable WHERE execid='go';" | tail -1)
echo ""
ok "Language: ${LANG}"
ok "Executable: ${EXEC}"

# ── Limpiar caché ─────────────────────────────────────────
info "Reiniciando domserver para limpiar caché..."
docker compose restart domserver
echo ""
echo "Siguiente paso:"
echo "  Ve a https://quipucode.lat/jury/languages"
echo "  Edita 'go' → Memory limit: 512000 KB"
echo ""
