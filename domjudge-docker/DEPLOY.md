# Tutorial de Despliegue — QuipuCode ⊕

> Guía completa para llevar QuipuCode a producción en un VPS Contabo desde cero.
> Tiempo estimado: **30–45 minutos**.

---

## Requisitos previos

| Requisito | Detalle |
|---|---|
| VPS Contabo | Ubuntu 22.04 LTS, mínimo 4 vCores / 6 GB RAM |
| Acceso SSH | Como `root` a la IP del VPS |
| Dominio | `quipucode.lat` con acceso al panel DNS |
| Cuenta GitHub | Acceso de lectura a `https://github.com/codeplai/quipucode` |

---

## Paso 0 — Configurar el DNS

Antes de obtener el certificado SSL, el dominio debe apuntar a la IP del VPS.

En tu panel DNS (Contabo, Cloudflare, Namecheap, etc.) crea **dos registros A**:

| Nombre | Tipo | Valor |
|---|---|---|
| `quipucode.lat` | A | `<IP_DE_TU_VPS>` |
| `www.quipucode.lat` | A | `<IP_DE_TU_VPS>` |

> La propagación DNS puede tardar entre 5 minutos y 2 horas.
> Puedes verificarla con: `nslookup quipucode.lat`

---

## Paso 1 — Conectarse al VPS

```bash
ssh root@<IP_DE_TU_VPS>
```

---

## Paso 2 — Clonar el repositorio

```bash
git clone https://github.com/codeplai/quipucode /opt/quipucode
cd /opt/quipucode/domjudge-docker
```

---

## Paso 3 — Preparar el servidor

```bash
bash scripts/setup_server.sh
```

Este script:
- Actualiza el sistema
- Instala **Docker**, **fail2ban**, **certbot**
- Crea 2 GB de swap (Contabo no incluye swap por defecto)
- Configura el firewall UFW (puertos 22, 80, 443, 12345)
- Habilita `cgroup memory` en GRUB para el judgehost

### ⚠ Si el script pide reiniciar

El script muestra este mensaje cuando modifica GRUB:

```
⚠ Se requiere REINICIAR el servidor.
⚠ Tras el reinicio ejecuta:
  bash scripts/setup_server.sh --post-reboot
```

Reinicia y ejecuta la fase 2:

```bash
reboot
# (reconecta por SSH)
cd /opt/quipucode/domjudge-docker
bash scripts/setup_server.sh --post-reboot
```

---

## Paso 4 — Configurar variables de entorno

```bash
cp .env.example .env
nano .env
```

Genera contraseñas seguras con este comando (**hex obligatorio** — base64 rompe la conexión):

```bash
openssl rand -hex 32   # ejecuta dos veces: una para cada contraseña
```

Edita `.env` con los valores generados:

```env
MYSQL_ROOT_PASSWORD=a3f8c2d1e9b47f6a0c5d8e3f2a1b4c7d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4
MYSQL_PASSWORD=1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2
JUDGEDAEMON_PASSWORD=   # ← se completa en el paso 7
```

> **Importante**: usa SOLO `openssl rand -hex 32` (hexadecimal). NO uses `base64` ni contraseñas
> con caracteres `+` `/` `=` `@` `#` — esos caracteres rompen la URL de conexión de la base de datos.

---

## Paso 5 — Obtener certificado SSL

> **El DNS debe estar propagado antes de este paso.**
> Verifica con `nslookup quipucode.lat` — debe devolver la IP del VPS.

```bash
SSL_EMAIL=hola@quipucode.lat bash scripts/setup_ssl.sh
```

El script:
1. Verifica que el DNS apunte al servidor
2. Obtiene el certificado de **Let's Encrypt** para `quipucode.lat` y `www.quipucode.lat`
3. Configura renovación automática (cron los días 1 y 15 de cada mes)

Salida esperada:
```
✓ Certificado obtenido en /etc/letsencrypt/live/quipucode.lat/
✓ Renovación automática configurada en /etc/cron.d/quipucode-ssl
```

---

## Paso 6 — Levantar la base de datos y el servidor web

```bash
docker compose up -d mariadb domserver
```

Espera ~30 segundos y luego obtén la **contraseña de admin** generada automáticamente:

```bash
docker compose logs domserver | grep -i "initial admin password"
```

Salida esperada:
```
Initial admin password: xKj9mPqR2vTn   ← ANOTA ESTA CONTRASEÑA
```

---

## Paso 7 — Obtener el JUDGEDAEMON_PASSWORD

```bash
docker compose exec domserver cat /opt/domjudge/domserver/etc/restapi.secret
```

Salida esperada:
```
default  http://domserver/api/  judgehost  Z5gkqaQwMEdG8I9v9NlGiLOUXlyG3eHz
                                           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                           ← copia este valor
```

Pega el valor en `.env`:

```bash
nano .env
# JUDGEDAEMON_PASSWORD=Z5gkqaQwMEdG8I9v9NlGiLOUXlyG3eHz
```

> Este es el **error más común** al desplegar DOMjudge.
> Sin este password el judgehost no puede registrarse.

---

## Paso 8 — Levantar todos los servicios

```bash
docker compose up -d --build
```

Esto construye el judgehost (con soporte Go) y levanta nginx con SSL.

Verifica que todos los contenedores estén corriendo:

```bash
docker compose ps
```

Salida esperada:
```
NAME              IMAGE                    STATUS
domjudge-docker-mariadb-1     mariadb:11         Up (healthy)
domjudge-docker-domserver-1   domjudge/domserver Up
domjudge-docker-nginx-1       nginx:alpine       Up
domjudge-docker-judgehost-0-1 domjudge-docker-j  Up
```

---

## Paso 9 — Aplicar identidad QuipuCode

```bash
bash scripts/setup_branding.sh
```

Actualiza el nombre del sitio en la base de datos y reinicia domserver.
El tema visual (paleta andina, chakana, patrón tocapu) ya está activo desde nginx.

---

## Paso 10 — Verificar el despliegue

Abre en tu navegador: **https://quipucode.lat**

Deberías ver la interfaz de QuipuCode con:
- 🔒 Candado SSL en la barra de direcciones
- Barra de navegación con degradado rojo/tierra
- Símbolo `⊕` antes del nombre
- Franja superior con patrón dorado/rojo

Accede al panel de jurado: **https://quipucode.lat/jury**
- Usuario: `admin`
- Contraseña: la anotada en el Paso 6

---

## Paso 11 — Configurar lenguajes

En **https://quipucode.lat/jury**:

1. Ir a **Languages → python3** → marcar **Enable** → Guardar
2. Ir a **Languages → go** → marcar **Enable** → cambiar **Memory limit** a `512000` (KB) → Guardar

> Go necesita mínimo 512 MB de memoria para su runtime.

---

## Paso 12 — Crear el concurso

Ir a **Jury → Contests → + Add contest**:

| Campo | Valor de ejemplo |
|---|---|
| Short name | `qc2025` |
| Name | `QuipuCode 2025` |
| Activate time | `2025-06-01 08:00:00 America/Lima` |
| Start time | `2025-06-01 09:00:00 America/Lima` |
| Freeze time | `2025-06-01 12:00:00 America/Lima` |
| End time | `2025-06-01 13:00:00 America/Lima` |
| Unfreeze time | `2025-06-01 13:30:00 America/Lima` |

---

## Paso 13 — Subir el problema de ejemplo

En el VPS:

```bash
bash problemas/empaquetar.sh
```

En el panel web:
1. **Jury → Problems → + Add** → seleccionar `problemas/ejemplo-suma.zip`
2. **Jury → Contests → [tu concurso] → Problems** → agregar el problema

---

## Paso 14 — Importar estudiantes

1. Copia tu Excel a `usuarios/estudiantes.xlsx` (ver formato en `usuarios/README.md`)
2. Genera los TSVs:

```bash
pip install pandas openpyxl
python scripts/excel_to_tsv.py usuarios/estudiantes.xlsx
```

3. En **Jury → Import/Export**:
   - Sube `usuarios/teams.tsv` → **Teams**
   - Sube `usuarios/accounts.tsv` → **Accounts**

---

## Paso 15 — Prueba final del sandbox

Inicia sesión como un equipo de prueba (`est001` / `Pass2024!`) y envía:

| Archivo | Veredicto esperado |
|---|---|
| `problemas/ejemplo-suma/submissions/accepted/sol.py` | ✅ Accepted |
| `problemas/ejemplo-suma/submissions/accepted/sol.go` | ✅ Accepted |
| `problemas/ejemplo-suma/submissions/wrong_answer/wa.py` | ❌ Wrong Answer |

---

## Mantenimiento

### Backup de la base de datos

```bash
cd /opt/quipucode/domjudge-docker
bash scripts/backup_db.sh
# Guarda en: backups/domjudge-YYYYMMDD-HHMMSS.sql
```

### Actualizar el código

```bash
cd /opt/quipucode
git pull
cd domjudge-docker
docker compose up -d --build
```

### Ver logs en tiempo real

```bash
docker compose logs -f domserver     # servidor web
docker compose logs -f judgehost-0   # juez
docker compose logs -f nginx         # proxy / SSL
```

### Reiniciar un servicio

```bash
docker compose restart domserver
docker compose restart judgehost-0
docker compose restart nginx
```

---

## Resumen de comandos (cheatsheet)

```bash
# ── Despliegue completo (orden correcto) ─────────────────────
git clone https://github.com/codeplai/quipucode /opt/quipucode
cd /opt/quipucode/domjudge-docker
bash scripts/setup_server.sh                          # (+ reboot si pide)
cp .env.example .env && nano .env                     # contraseñas
SSL_EMAIL=tu@email.com bash scripts/setup_ssl.sh      # certificado
docker compose up -d mariadb domserver                # BD + web
docker compose logs domserver | grep "admin password" # anotar password
# → editar .env con JUDGEDAEMON_PASSWORD
docker compose up -d --build                          # nginx + judgehost
bash scripts/setup_branding.sh                        # identidad QuipuCode

# ── Mantenimiento ────────────────────────────────────────────
docker compose ps                   # estado de los contenedores
docker compose logs -f              # logs en tiempo real
bash scripts/backup_db.sh           # backup de la BD
git pull && docker compose up -d --build  # actualizar
```

---

*QuipuCode — Tejiendo código en el Tawantinsuyu ⊕*
