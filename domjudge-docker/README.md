# QuipuCode ⊕

**Plataforma de Programación Competitiva** — *Tejiendo código en el Tawantinsuyu*

Juez automático con soporte para **Go** y **Python 3**, completamente dockerizado.
Basado en DOMjudge con identidad visual Inca.

| Acceso          | URL                           |
|-----------------|-------------------------------|
| Producción      | `https://quipucode.xyz`       |
| Local           | `http://localhost`            |
| Debug (directo) | `http://localhost:12345`      |

---

## Pre-requisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Windows/Mac) o Docker Engine + Compose v2 (Linux)
- En Windows: WSL2 habilitado con kernel reciente (requerido para cgroups del judgehost)

---

## Guía de despliegue end-to-end

### 1. Configurar variables de entorno

```bash
cp .env.example .env
```

Edita `.env` con contraseñas seguras. **No uses los valores de ejemplo en producción.**

```
MYSQL_ROOT_PASSWORD=contraseña-root-segura
MYSQL_PASSWORD=contraseña-domjudge-segura
JUDGEDAEMON_PASSWORD=   # se completa en el paso 3
```

### 2. Primer arranque (mariadb + domserver)

```bash
docker compose up -d mariadb domserver
```

Espera ~30 segundos a que MariaDB inicialice, luego observa los logs:

```bash
docker compose logs domserver | grep -i "initial admin password"
```

**Anota el password de `admin`** — lo necesitarás para acceder al panel.

### 3. Obtener el JUDGEDAEMON_PASSWORD

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

### 4. Levantar nginx y el judgehost

```bash
docker compose up -d --build
```

Verifica que el judgehost aparezca como activo en **Admin → Judgehosts**.

### 5. Aplicar identidad QuipuCode

```bash
bash scripts/setup_branding.sh
```

Esto actualiza el nombre del sitio en la base de datos y reinicia domserver.
El tema visual (colores incas, chakana, patrón tocapu) se aplica automáticamente vía nginx.

### 6. Habilitar lenguajes

En el panel de administración (`http://localhost/jury`):

- **Languages → python3** → Enable ✓
- **Languages → go** → Enable ✓, Memory limit: `512000` KB (512 MB mínimo para Go)

### 7. Crear un concurso

Ir a **Jury → Contests → New** y configurar:

| Campo      | Descripción                              |
|------------|------------------------------------------|
| `activate` | Cuándo es visible para equipos           |
| `start`    | Inicio oficial (acepta envíos)           |
| `freeze`   | Scoreboard se congela (ej: última hora)  |
| `end`      | Fin del concurso (rechaza envíos)        |
| `unfreeze` | Se publica scoreboard final              |

### 8. Subir el problema de ejemplo

```bash
bash problemas/empaquetar.sh
```

Luego en **Jury → Problems → Add** selecciona `problemas/ejemplo-suma.zip`.

Asigna el problema al concurso en **Jury → Contests → [tu concurso] → Problems**.

### 9. Importar estudiantes desde Excel

1. Copia tu Excel al path `usuarios/estudiantes.xlsx` (ver formato en [usuarios/README.md](usuarios/README.md)).
2. Genera los TSVs:

```bash
pip install pandas openpyxl
python scripts/excel_to_tsv.py usuarios/estudiantes.xlsx
```

3. En **Jury → Import/Export**:
   - Sube `usuarios/teams.tsv`
   - Sube `usuarios/accounts.tsv`

### 10. Verificar el sandbox

Inicia sesión como equipo de prueba y envía:

- `submissions/accepted/sol.go` → debe dar veredicto **AC**
- `submissions/accepted/sol.py` → debe dar veredicto **AC**
- `submissions/wrong_answer/wa.py` → debe dar veredicto **WA**

### 11. Backup de la base de datos

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

| Elemento              | Significado Inca                              |
|-----------------------|-----------------------------------------------|
| `⊕` (chakana)         | Cruz andina, símbolo del orden cósmico Inca   |
| Dorado `#D4A017`      | Color del Sol (Inti), dios supremo Inca       |
| Rojo imperial `#7A1F1F` | Color de la nobleza y el poder Inca         |
| Marrón tierra `#4A2C0A` | Pacha Mama, madre tierra andina             |
| Patrón tocapu          | Franja superior inspirada en textiles Inca   |
| "Tejiendo código"      | El **Quipu** fue el sistema de registro Inca |

Los archivos de tema están en [branding/quipucode-theme.css](branding/quipucode-theme.css).
La configuración del proxy (inyección de CSS + reemplazo de nombre) está en [nginx/nginx.conf](nginx/nginx.conf).

---

## Estructura del proyecto

```
domjudge-docker/
├── docker-compose.yml          # orquestación de los 4 servicios
├── .env.example                # plantilla de variables de entorno
├── .gitignore
├── nginx/
│   └── nginx.conf              # proxy inverso + tema QuipuCode
├── branding/
│   └── quipucode-theme.css     # paleta andina (Inti, Pacha Mama, Chakana)
├── judgehost/
│   └── Dockerfile              # judgehost oficial + Go
├── scripts/
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

**Solución:**
```bash
docker compose exec domserver cat /opt/domjudge/domserver/etc/restapi.secret
# Copia el password, pégalo en .env
docker compose restart judgehost-0
```

### 2. TLE inesperado en Go

**Causa:** El límite de memoria del lenguaje Go es demasiado bajo (el runtime de Go necesita ≥ 512 MB).

**Solución:** En **Admin → Languages → go** → Memory limit: `512000` (KB).

### 3. Error 500 al subir el ZIP del problema

**Causa:** `problem.yaml` malformado o los archivos en `data/` no tienen los permisos correctos.

**Solución:** Verifica la estructura del ZIP:
```bash
unzip -l problemas/ejemplo-suma.zip
```
Debe mostrar `problem.yaml`, `domjudge-problem.ini`, `data/sample/`, `data/secret/`.

### 4. "Cannot connect to MySQL" en los logs de domserver

**Causa:** MariaDB todavía está inicializando (normal en el primer arranque, puede tardar 30-60s).

**Solución:** Espera y vuelve a verificar:
```bash
docker compose logs mariadb --tail 20
```
Cuando aparezca `ready for connections`, levanta domserver.

### 5. Cgroups v2 incompatibles (judgehost falla al iniciar)

**Causa:** Kernels recientes usan cgroups v2 por defecto, el judgehost antiguo espera v1.

**Solución A (host Linux):** Añade `systemd.unified_cgroup_hierarchy=0` a los parámetros del kernel.

**Solución B:** Usa imagen `domjudge/judgehost` versión ≥ 8.3 que soporta cgroups v2.

**Solución C (Windows/WSL2):** Asegúrate de usar WSL2 con kernel ≥ 5.15.

### 6. El tema QuipuCode no se aplica

**Causa:** El CSS no está siendo inyectado correctamente.

**Diagnóstico:**
```bash
docker compose logs nginx --tail 20
curl -I http://localhost/quipucode-theme.css
```

**Solución:** Verifica que el volumen esté montado:
```bash
docker compose exec nginx ls /usr/share/nginx/html/quipucode-theme.css
```
