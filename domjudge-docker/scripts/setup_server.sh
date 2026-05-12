#!/usr/bin/env bash
# Ejecutar como root en Ubuntu 22.04 recién instalado:
#   bash scripts/setup_server.sh
set -euo pipefail

echo "=== 1. Actualizando sistema ==="
apt-get update && apt-get upgrade -y

echo "=== 2. Instalando Docker ==="
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "=== 3. Habilitando cgroup memory (necesario para el judgehost) ==="
if ! grep -q "cgroup_enable=memory" /etc/default/grub; then
  sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 cgroup_enable=memory swapaccount=1"/' /etc/default/grub
  update-grub
  echo "AVISO: Se modificó GRUB. Reinicia el servidor antes de continuar."
  echo "       Después del reinicio vuelve a ejecutar: bash scripts/setup_server.sh --post-reboot"
  exit 0
fi

echo "=== 4. Configurando firewall ==="
ufw allow OpenSSH
ufw allow 80/tcp
ufw --force enable

echo "=== Listo. Sigue con el README para levantar DOMjudge. ==="
