#!/usr/bin/env bash
# Añade el lenguaje Go a DOMjudge directamente en la base de datos.
# Uso: bash scripts/add_go_language.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."
source .env

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
info() { echo -e "${YELLOW}→${NC} $*"; }

db() {
  docker compose exec -T mariadb \
    mariadb -u root -p"${MYSQL_ROOT_PASSWORD}" domjudge -e "$1"
}

echo ""
echo "╔══════════════════════════════════════╗"
echo "║  QuipuCode — Añadir lenguaje Go      ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ── 1. Si Go ya existe, solo habilitarlo ───────────────────
GO_COUNT=$(db "SELECT COUNT(*) FROM language WHERE langid='go';" | tail -1 | tr -d '[:space:]')

if [ "$GO_COUNT" = "1" ]; then
  info "Go ya existe en la BD — habilitando..."
  db "UPDATE language SET allow_submit=1, allow_judge=1 WHERE langid='go';"
  ok "Go habilitado. Refresca https://quipucode.lat/jury/languages"
  exit 0
fi

info "Go no está en BD. Creando ejecutable y lenguaje..."

# ── 2. Crear el script de compilación ─────────────────────
mkdir -p /tmp/qc_go_exec
cat > /tmp/qc_go_exec/build << 'BUILDSCRIPT'
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
chmod +x /tmp/qc_go_exec/build

# ── 3. Crear el ZIP ────────────────────────────────────────
cd /tmp/qc_go_exec
zip -q /tmp/compile_go.zip build
cd "${SCRIPT_DIR}/.."

HEX=$(xxd -p /tmp/compile_go.zip | tr -d '\n')
MD5=$(md5sum /tmp/compile_go.zip | cut -d' ' -f1)
info "ZIP: $((${#HEX}/2)) bytes — MD5: ${MD5}"

# ── 4. Generar SQL en archivo temporal ────────────────────
SQL_FILE="/tmp/add_go_$(date +%s).sql"
cat > "${SQL_FILE}" << SQLEOF
INSERT IGNORE INTO executable (execid, type, description, zipfile, md5sum)
VALUES ('compile_go', 'compile', 'Go compile script', 0x${HEX}, '${MD5}');

INSERT IGNORE INTO language
  (langid, externalid, name, extensions,
   require_entry_point, entry_point_description,
   allow_submit, allow_judge, time_factor,
   compile_execid, filter_compiler_files)
VALUES
  ('go', 'go', 'Go', '["go"]',
   0, NULL,
   1, 1, 1,
   'compile_go', 1);
SQLEOF

# ── 5. Ejecutar SQL (stdin, no heredoc) ───────────────────
docker compose exec -T mariadb \
  mariadb -u root -p"${MYSQL_ROOT_PASSWORD}" domjudge \
  < "${SQL_FILE}"

rm -f "${SQL_FILE}"

# ── 6. Verificar ─────────────────────────────────────────
RESULT=$(db "SELECT langid, name, allow_submit FROM language WHERE langid='go';" | tail -1)
echo ""
ok "Resultado en BD: ${RESULT}"
echo ""
echo "Siguiente paso:"
echo "  1. Ve a https://quipucode.lat/jury/languages"
echo "  2. Edita 'go' → Memory limit: 512000 KB"
echo ""
