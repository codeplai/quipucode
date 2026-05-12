# QuipuCode ⊕

**Plataforma de Programación Competitiva** — *Tejiendo código en el Tawantinsuyu*

Juez automático con soporte para **Go** y **Python 3**, completamente dockerizado.
Desplegado sobre VPS Contabo con Ubuntu 22.04 LTS.

| Acceso          | URL                            |
|-----------------|--------------------------------|
| Producción      | `https://quipucode.lat`        |
| Local           | `http://localhost`             |
| Debug (directo) | `http://localhost:12345`       |

---

## Pre-requisitos

- VPS Contabo con **Ubuntu 22.04 LTS** (recomendado: 4 vCores, 6 GB RAM)
- Registro DNS `A` de `quipucode.lat` y `www.quipucode.lat` apuntando a la IP del VPS
- Acceso root por SSH

---

## Guía de despliegue end-to-end

### 1. Preparar el servidor (Contabo VPS)

```bash
# En el VPS como root:
git clone <repositorio> /opt/quipucode
cd /opt/quipucode
bash scripts/setup_server.sh
```

El script instala Docker, fail2ban, certbot, configura UFW y habilita cgroups memory.
Si modifica GRUB, **reinicia el servidor** y luego ejecuta:

```bash
bash scripts/setup_server.sh --post-reboot
```

### 2. Configurar variables de entorno

```bash
cp .env.example .env
```

Edita `.env` con contraseñas seguras:

```
MYSQL_ROOT_PASSWORD=contraseña-root-segura
MYSQL_PASSWORD=contraseña-domjudge-segura
JUDGEDAEMON_PASSWORD=   # se completa en el paso 4
```

### 3. Obtener certificado SSL

```bash
# El DNS debe estar apuntando al VPS antes de este paso
SSL_EMAIL=tu@email.com bash scripts/setup_ssl.sh
```

Obtiene el certificado de Let's Encrypt para `quipucode.lat` y configura la renovación automática.

### 4. Primer arranque (mariadb + domserver)

```bash
docker compose up -d mariadb domserver
```

Espera ~30 segundos, luego obtén la contraseña de admin:

```bash
docker compose logs domserver | grep -i "initial admin password"
```

### 5. Obtener el JUDGEDAEMON_PASSWORD

```bash
docker compose exec domserver cat /opt/domjudge/domserver/etc/restapi.secret
```

La salida tiene el formato:

```
default  http://domserver/api/  judgehost  <PASSWORD_AQUI>
```

Copia `<PASSWORD_AQUI>` y pégalo en `.env`:

```
JUDGEDAEMON_PASSWORD=<PASSWORD_AQUI>
```

> Este paso es el **error #1** al desplegar. Sin el password correcto el judgehost no puede registrarse.

### 6. Levantar todos los servicios

```bash
docker compose up -d --build
```

Verifica que el judgehost aparezca como activo en **Admin → Judgehosts**.

### 7. Aplicar identidad QuipuCode

```bash
bash scripts/setup_branding.sh
```

Actualiza el nombre del sitio en la base de datos y reinicia domserver.
El tema visual (colores incas, chakana, patrón tocapu) se aplica automáticamente vía nginx.

### 8. Habilitar lenguajes

En el panel de administración (`https://quipucode.lat/jury`):

- **Languages → python3** → Enable ✓
- **Languages → go** → Enable ✓, Memory limit: `512000` KB (512 MB mínimo para Go)

### 9. Crear un concurso

Ir a **Jury → Contests → New** y configurar:

| Campo      | Descripción                              |
|------------|------------------------------------------|
| `activate` | Cuándo es visible para equipos           |
| `start`    | Inicio oficial (acepta envíos)           |
| `freeze`   | Scoreboard se congela (ej: última hora)  |
| `end`      | Fin del concurso (rechaza envíos)        |
| `unfreeze` | Se publica scoreboard final              |

### 10. Subir el problema de ejemplo

```bash
bash problemas/empaquetar.sh
```

Luego en **Jury → Problems → Add** selecciona `problemas/ejemplo-suma.zip`.

Asigna el problema al concurso en **Jury → Contests → [tu concurso] → Problems**.

### 11. Importar estudiantes desde Excel

1. Copia tu Excel al path `usuarios/estudiantes.xlsx` (ver formato en [usuarios/README.md](usuarios/README.md)).
2. Genera los TSVs:

```bash
pip install pandas openpyxl
python scripts/excel_to_tsv.py usuarios/estudiantes.xlsx
```

3. En **Jury → Import/Export**:
   - Sube `usuarios/teams.tsv`
   - Sube `usuarios/accounts.tsv`

### 12. Verificar el sandbox

Inicia sesión como equipo de prueba y envía:

- `submissions/accepted/sol.go` → debe dar veredicto **AC**
- `submissions/accepted/sol.py` → debe dar veredicto **AC**
- `submissions/wrong_answer/wa.py` → debe dar veredicto **WA**

### 13. Backup de la base de datos

```bash
bash scripts/backup_db.sh
```

El archivo `.sql` se guarda en `backups/`. Para restaurar:

```bash
bash scripts/restore_db.sh backups/domjudge-YYYYMMDD-HHMMSS.sql
```

---

## Identidad visual QuipuCode

La plataforma incorpora el espíritu del **Tawantinsuyu** en su interfaz:

| Elemento               | Significado Inca                              |
|------------------------|-----------------------------------------------|
| `⊕` (chakana)          | Cruz andina, símbolo del orden cósmico Inca   |
| Dorado `#D4A017`       | Color del Sol (Inti), dios supremo Inca       |
| Rojo imperial `#7A1F1F`| Color de la nobleza y el poder Inca           |
| Marrón tierra `#4A2C0A`| Pacha Mama, madre tierra andina               |
| Patrón tocapu           | Franja superior inspirada en textiles Inca    |
| "Tejiendo código"       | El **Quipu** fue el sistema de registro Inca  |

Los archivos de tema están en [branding/quipucode-theme.css](branding/quipucode-theme.css).
La configuración del proxy (SSL + inyección de CSS) está en [nginx/nginx.conf](nginx/nginx.conf).

---

## Estructura del proyecto

```
domjudge-docker/
├── docker-compose.yml          # orquestación: mariadb, domserver, nginx, judgehost
├── .env.example                # plantilla de variables de entorno
├── .gitignore
├── nginx/
│   └── nginx.conf              # proxy inverso HTTPS + tema QuipuCode
├── branding/
│   └── quipucode-theme.css     # paleta andina (Inti, Pacha Mama, Chakana)
├── judgehost/
│   └── Dockerfile              # judgehost oficial + Go
├── scripts/
│   ├── setup_server.sh         # prepara el VPS Contabo (Ubuntu 22.04)
│   ├── setup_ssl.sh            # obtiene certificado SSL Let's Encrypt
│   ├── setup_branding.sh       # aplica identidad QuipuCode en BD
│   ├── excel_to_tsv.py         # convierte Excel → accounts.tsv + teams.tsv
│   ├── backup_db.sh            # mysqldump del estado
│   └── restore_db.sh           # restaura desde .sql
├── problemas/
│   ├── empaquetar.sh           # genera ejemplo-suma.zip
│   └── ejemplo-suma/           # problema completo de validación
├── usuarios/
│   ├── README.md               # formato del Excel
│   └── estudiantes.xlsx        # (NO versionado, añadir por el usuario)
└── backups/                    # (NO versionado)
```

---

## Escalado horizontal (múltiples judgehosts)

Para añadir más judgehosts, duplica el servicio en `docker-compose.yml` cambiando el `DAEMON_ID` y el `hostname`:

```yaml
judgehost-1:
  build: ./judgehost
  privileged: true
  hostname: judgehost-1
  depends_on: [domserver]
  environment:
    DAEMON_ID: 1
    JUDGEDAEMON_PASSWORD: ${JUDGEDAEMON_PASSWORD}
    DOMSERVER_BASEURL: http://domserver/
  links: [domserver]
  restart: unless-stopped
```

---

## Troubleshooting

### 1. Judgehost en estado "no judgings" o no aparece en la lista

**Causa:** `JUDGEDAEMON_PASSWORD` incorrecto o vacío en `.env`.

```bash
docker compose exec domserver cat /opt/domjudge/domserver/etc/restapi.secret
# Copia el password, pégalo en .env
docker compose restart judgehost-0
```

### 2. TLE inesperado en Go

**Causa:** Límite de memoria del lenguaje Go demasiado bajo (el runtime necesita ≥ 512 MB).

**Solución:** **Admin → Languages → go** → Memory limit: `512000` (KB).

### 3. Error 500 al subir el ZIP del problema

```bash
unzip -l problemas/ejemplo-suma.zip
```
Debe mostrar `problem.yaml`, `domjudge-problem.ini`, `data/sample/`, `data/secret/`.

### 4. "Cannot connect to MySQL" en logs de domserver

MariaDB todavía está inicializando. Espera y verifica:

```bash
docker compose logs mariadb --tail 20
# Cuando aparezca "ready for connections", levanta domserver.
```

### 5. "Malformed database connection URL" — domserver en bucle

**Causa:** La contraseña en `.env` contiene caracteres especiales (`+`, `/`, `=`, `@`) que
rompen la URL de conexión que DOMjudge construye internamente (`mysql://user:PASS@host/db`).
Ocurre al usar `openssl rand -base64 32`.

**Solución:**
```bash
docker compose down -v                  # borra todo (incluido el volumen de BD)
openssl rand -hex 32                    # genera password SIN caracteres especiales
# Edita .env con los nuevos valores hex
nano .env
docker compose up -d mariadb domserver  # reinicia limpio
```

**Regla:** usa siempre `openssl rand -hex 32` para las contraseñas de `.env`.

### 6. Cgroups v2 incompatibles (judgehost falla al iniciar)

En Ubuntu 22.04, `setup_server.sh` ya configura `cgroup_enable=memory` en GRUB.
Si el problema persiste:

```bash
grep cgroup /proc/cmdline          # debe mostrar cgroup_enable=memory
docker compose logs judgehost-0    # ver el error exacto
```

Solución alternativa: usa imagen `domjudge/judgehost` versión ≥ 8.3.

### 6. SSL: nginx no arranca (certificados no encontrados)

```bash
# Verifica que existan los certificados en el host
ls /etc/letsencrypt/live/quipucode.lat/
# Si no existen, ejecuta:
bash scripts/setup_ssl.sh
```

### 7. El tema QuipuCode no se aplica

```bash
docker compose logs nginx --tail 20
curl -I https://quipucode.lat/quipucode-theme.css   # debe responder 200
docker compose exec nginx ls /usr/share/nginx/html/quipucode-theme.css
```
