#!/usr/bin/env bash
# Configura la identidad QuipuCode en la base de datos de DOMjudge.
# Ejecutar UNA VEZ después de que domserver haya terminado de inicializarse.
#
# Uso:
#   bash scripts/setup_branding.sh
#
# Requiere que los servicios estén levantados:
#   docker compose up -d mariadb domserver

set -euo pipefail

# Cargar contraseñas del archivo .env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "[ERROR] No se encontró el archivo .env en: $ENV_FILE"
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║    QuipuCode — Configuración de Identidad    ║"
echo "║    Tawantinsuyu de la Programación           ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# Esperar a que domserver haya creado las tablas
echo "⏳ Esperando que domserver inicialice la base de datos..."
RETRIES=20
until docker compose exec mariadb mariadb -u root -p"${MYSQL_ROOT_PASSWORD}" domjudge \
      -e "SELECT 1 FROM configuration LIMIT 1;" &>/dev/null; do
  RETRIES=$((RETRIES - 1))
  if [ "$RETRIES" -le 0 ]; then
    echo "[ERROR] Timeout esperando la tabla 'configuration'. ¿Está domserver levantado?"
    exit 1
  fi
  echo "   ... esperando ($RETRIES intentos restantes)"
  sleep 5
done

echo "✓ Tablas listas."
echo ""

# Actualizar (o insertar) el nombre del sitio
docker compose exec mariadb mariadb -u root -p"${MYSQL_ROOT_PASSWORD}" domjudge <<'SQL'
INSERT INTO configuration (name, value, type, public, category, description)
VALUES (
  'domjudge_site_name',
  '"QuipuCode"',
  'string',
  1,
  'General',
  'Nombre de la plataforma de programación competitiva'
)
ON DUPLICATE KEY UPDATE value = '"QuipuCode"';
SQL

echo "✓ Nombre del sitio → QuipuCode"
echo ""

# Reiniciar domserver para que el caché de Symfony refleje el cambio
echo "🔄 Reiniciando domserver para aplicar cambios..."
docker compose restart domserver

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  ✓ QuipuCode configurado exitosamente        ║"
echo "║                                              ║"
echo "║  Acceso: http://quipucode.lat                ║"
echo "║  Local:  http://localhost                    ║"
echo "║  Debug:  http://localhost:12345              ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
