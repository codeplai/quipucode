#!/usr/bin/env bash
# ============================================================
#  QuipuCode — Preparación del VPS Contabo (Ubuntu 22.04)
#  Ejecutar como root: bash scripts/setup_server.sh
#
#  Fases:
#    Fase 1 (primer run): instala todo y modifica GRUB
#    Fase 2 (post-reboot): bash scripts/setup_server.sh --post-reboot
# ============================================================
set -euo pipefail

POST_REBOOT=false
[[ "${1:-}" == "--post-reboot" ]] && POST_REBOOT=true

DOMAIN="quipucode.lat"
PROJECT_DIR="/opt/quipucode"
DEPLOY_USER="quipucode"

# ── Colores para output ──────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
die()  { echo -e "${RED}✗${NC} $*"; exit 1; }

# ════════════════════════════════════════════════════════════
#  FASE 2 — POST-REBOOT
# ════════════════════════════════════════════════════════════
if $POST_REBOOT; then
  echo ""
  echo "╔══════════════════════════════════════════════╗"
  echo "║  QuipuCode — Fase 2: post-reinicio           ║"
  echo "╚══════════════════════════════════════════════╝"
  echo ""

  # Verificar cgroups activos
  if grep -q "cgroup_enable=memory" /proc/cmdline; then
    ok "cgroups memory habilitado."
  else
    warn "cgroup_enable=memory no detectado en cmdline. Verifica GRUB."
  fi

  # Crear usuario de despliegue sin privilegios
  if ! id "$DEPLOY_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$DEPLOY_USER"
    usermod -aG docker "$DEPLOY_USER"
    ok "Usuario '$DEPLOY_USER' creado y añadido al grupo docker."
  else
    ok "Usuario '$DEPLOY_USER' ya existe."
  fi

  # Crear directorio del proyecto
  mkdir -p "$PROJECT_DIR"
  chown "$DEPLOY_USER:$DEPLOY_USER" "$PROJECT_DIR"
  ok "Directorio del proyecto: $PROJECT_DIR"

  echo ""
  echo "╔══════════════════════════════════════════════╗"
  echo "║  ✓ Servidor listo para despliegue            ║"
  echo "║                                              ║"
  echo "║  Próximos pasos:                             ║"
  echo "║  1. Copia el proyecto a $PROJECT_DIR         ║"
  echo "║  2. cd $PROJECT_DIR && cp .env.example .env  ║"
  echo "║  3. Edita .env con contraseñas seguras       ║"
  echo "║  4. bash scripts/setup_ssl.sh                ║"
  echo "║  5. docker compose up -d                     ║"
  echo "╚══════════════════════════════════════════════╝"
  echo ""
  exit 0
fi

# ════════════════════════════════════════════════════════════
#  FASE 1 — INSTALACIÓN INICIAL
# ════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  QuipuCode — Preparación VPS Contabo         ║"
echo "║  Ubuntu 22.04 LTS                            ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

[ "$(id -u)" -eq 0 ] || die "Ejecutar como root."
. /etc/os-release
[[ "$ID" == "ubuntu" && "$VERSION_ID" == "22.04" ]] \
  || warn "Este script está optimizado para Ubuntu 22.04 (detectado: $PRETTY_NAME)."

# ── 1. Actualizar sistema ────────────────────────────────────
echo "=== 1. Actualizando sistema ==="
apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -q
ok "Sistema actualizado."

# ── 2. Dependencias base ─────────────────────────────────────
echo "=== 2. Instalando dependencias base ==="
DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
  ca-certificates curl gnupg unzip git \
  fail2ban ufw certbot \
  htop iotop ncdu
ok "Dependencias instaladas."

# ── 3. Docker Engine ─────────────────────────────────────────
echo "=== 3. Instalando Docker ==="
if command -v docker &>/dev/null; then
  ok "Docker ya instalado: $(docker --version)"
else
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -q
  DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
    docker-ce docker-ce-cli containerd.io docker-compose-plugin
  systemctl enable --now docker
  ok "Docker instalado: $(docker --version)"
fi

# ── 4. Parámetros del kernel (judgehost + red) ───────────────
echo "=== 4. Optimizando parámetros del kernel ==="
cat > /etc/sysctl.d/99-quipucode.conf <<'SYSCTL'
# QuipuCode — tunables para VPS Contabo
net.core.somaxconn            = 65535
net.ipv4.tcp_max_syn_backlog  = 65535
net.ipv4.ip_local_port_range  = 1024 65535
fs.file-max                   = 1000000
vm.swappiness                 = 10
SYSCTL
sysctl -p /etc/sysctl.d/99-quipucode.conf -q
ok "Parámetros del kernel aplicados."

# ── 5. Swap (Contabo no incluye swap por defecto) ────────────
echo "=== 5. Configurando swap ==="
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
  ok "Swap de 2 GB creada y activada."
else
  ok "Swap ya configurada."
fi

# ── 6. Fail2ban (protección SSH) ─────────────────────────────
echo "=== 6. Configurando fail2ban ==="
cat > /etc/fail2ban/jail.d/quipucode.conf <<'F2B'
[sshd]
enabled  = true
maxretry = 5
bantime  = 3600
findtime = 600
F2B
systemctl enable --now fail2ban
ok "fail2ban activo."

# ── 7. Firewall UFW ──────────────────────────────────────────
echo "=== 7. Configurando UFW ==="
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 12345/tcp comment "QuipuCode debug"
ufw --force enable
ok "UFW configurado: SSH, 80, 443, 12345."

# ── 8. Cgroups — modificar GRUB (requiere reinicio) ─────────
echo "=== 8. Habilitando cgroup memory para judgehost ==="
GRUB_CFG=/etc/default/grub
if ! grep -q "cgroup_enable=memory" "$GRUB_CFG"; then
  sed -i \
    's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 cgroup_enable=memory swapaccount=1"/' \
    "$GRUB_CFG"
  update-grub
  ok "GRUB modificado."
  echo ""
  warn "Se requiere REINICIAR el servidor."
  warn "Tras el reinicio ejecuta:"
  warn "  bash scripts/setup_server.sh --post-reboot"
  echo ""
  exit 0
else
  ok "cgroup_enable=memory ya estaba configurado."
fi

# Si llegamos aquí, GRUB no necesitó cambios — correr fase 2 directamente
bash "$0" --post-reboot
