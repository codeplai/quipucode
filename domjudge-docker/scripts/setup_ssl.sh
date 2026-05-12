#!/usr/bin/env bash
# ============================================================
#  QuipuCode — Certificado SSL con Let's Encrypt
#  Ejecutar como root desde /opt/quipucode ANTES de levantar nginx.
#
#  Uso:
#    bash scripts/setup_ssl.sh
#    SSL_EMAIL=admin@quipucode.lat bash scripts/setup_ssl.sh
# ============================================================
set -euo pipefail

DOMAIN="quipucode.lat"
EMAIL="${SSL_EMAIL:-}"

# ── Colores ──────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
die()  { echo -e "${RED}✗${NC} $*"; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Ejecutar como root."

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  QuipuCode — Certificado SSL                 ║"
echo "║  Let's Encrypt para $DOMAIN          ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── Verificar que el DNS apunta a este servidor ──────────────
SERVER_IP=$(curl -s --max-time 5 https://api.ipify.org || echo "desconocida")
RESOLVED_IP=$(getent hosts "$DOMAIN" 2>/dev/null | awk '{print $1}' | head -1 || echo "no_resuelve")

echo "IP pública del servidor : $SERVER_IP"
echo "IP resuelta de $DOMAIN : $RESOLVED_IP"
echo ""

if [ "$SERVER_IP" != "$RESOLVED_IP" ]; then
  warn "El DNS de $DOMAIN ($RESOLVED_IP) no coincide con la IP del servidor ($SERVER_IP)."
  warn "Configura el registro A de $DOMAIN en tu panel DNS antes de continuar."
  read -rp "¿Continuar de todos modos? [s/N] " RESP
  [[ "${RESP,,}" == "s" ]] || exit 0
fi

# ── Obtener email si no se proporcionó ───────────────────────
if [ -z "$EMAIL" ]; then
  read -rp "Email para notificaciones de renovación SSL: " EMAIL
  [ -n "$EMAIL" ] || die "El email es obligatorio."
fi

# ── Verificar que certbot esté instalado ─────────────────────
if ! command -v certbot &>/dev/null; then
  echo "Instalando certbot..."
  apt-get update -q
  apt-get install -y -q certbot
fi

# ── Limpiar cuentas ACME corruptas o de otra máquina ────────────
ACME_ACCOUNTS="/etc/letsencrypt/accounts/acme-v02.api.letsencrypt.org"
if [ -d "$ACME_ACCOUNTS" ]; then
  # Detectar si la cuenta local ya no existe en el servidor ACME
  ACME_DIR=$(find "$ACME_ACCOUNTS" -name "meta.json" -print -quit 2>/dev/null || true)
  if [ -n "$ACME_DIR" ]; then
    ACME_URL=$(python3 -c "import json,sys; d=json.load(open('$ACME_DIR')); print(d.get('uri',''))" 2>/dev/null || true)
    if [ -n "$ACME_URL" ]; then
      HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$ACME_URL" || echo "000")
      if [ "$HTTP_CODE" = "404" ] || [ "$HTTP_CODE" = "000" ]; then
        warn "Cuenta ACME local inválida (HTTP $HTTP_CODE). Limpiando..."
        rm -rf /etc/letsencrypt/accounts/
        ok "Cuenta ACME eliminada. Se registrará una nueva."
      fi
    fi
  fi
fi

# ── Detener nginx si está corriendo (certbot necesita el puerto 80) ──
if docker compose ps nginx 2>/dev/null | grep -q "Up"; then
  echo "Deteniendo nginx temporalmente..."
  docker compose stop nginx
  NGINX_WAS_RUNNING=true
else
  NGINX_WAS_RUNNING=false
fi

# ── Obtener certificado ───────────────────────────────────────
echo "Obteniendo certificado para $DOMAIN y www.$DOMAIN ..."
certbot certonly \
  --standalone \
  --non-interactive \
  --agree-tos \
  --email "$EMAIL" \
  -d "$DOMAIN" \
  -d "www.$DOMAIN" \
  --keep-until-expiring

ok "Certificado obtenido en /etc/letsencrypt/live/$DOMAIN/"

# ── Reiniciar nginx con SSL ───────────────────────────────────
if $NGINX_WAS_RUNNING; then
  echo "Reiniciando nginx con SSL..."
  docker compose start nginx
  ok "nginx reiniciado."
fi

# ── Renovación automática (cron) ─────────────────────────────
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRON_FILE="/etc/cron.d/quipucode-ssl"

cat > "$CRON_FILE" <<CRON
# Renovación automática del certificado SSL de QuipuCode
# Corre a las 3:15 AM los días 1 y 15 de cada mes
15 3 1,15 * * root \
  cd $PROJECT_DIR && \
  docker compose stop nginx && \
  certbot renew --quiet && \
  docker compose start nginx
CRON
chmod 644 "$CRON_FILE"
ok "Renovación automática configurada en $CRON_FILE"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  ✓ SSL listo para quipucode.lat              ║"
echo "║                                              ║"
echo "║  Certif.: /etc/letsencrypt/live/$DOMAIN/  ║"
echo "║  Renueva: automático (cron)                  ║"
echo "║                                              ║"
echo "║  Siguiente paso:                             ║"
echo "║    docker compose up -d                      ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
