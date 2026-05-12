# DOMjudge en Docker — Especificación para Claude Code

> Prompt-guía para que Claude Code construya un entorno DOMjudge completo, dockerizado, con sandbox para Go y Python, importación masiva de usuarios y gestión de concursos con límite de tiempo.

---

## Contexto

Necesito desplegar **DOMjudge** (juez automático de programación competitiva) en mi máquina/servidor usando Docker, para que mis estudiantes resuelvan problemas en concursos cronometrados.

**Stack objetivo:**
- DOMjudge `domserver` (web + API)
- MariaDB (persistencia)
- Uno o más `judgehost` (sandbox de ejecución)
- Lenguajes habilitados: **Go** y **Python 3**

---

## Requisitos funcionales

1. **Sandbox seguro** que ejecute código en Go y Python con límites de tiempo, memoria y sin acceso a red.
2. **Carga de problemas** mediante ZIPs en formato Kattis/CLICS estándar.
3. **Importación masiva de usuarios** desde un archivo Excel (`.xlsx`) con columnas `username`, `password`, `nombre_completo`, opcionalmente `grupo`.
4. **Concursos cronometrados**: poder fijar `activate`, `start`, `freeze`, `end`, `unfreeze`. Cuando llega `end`, el sistema rechaza envíos automáticamente.
5. **Backups** sencillos del estado (BD).
6. **Acceso web** en `http://localhost:12345` (configurable).

---

## Tareas que debe ejecutar Claude Code

### Tarea 1 — Estructura del proyecto

Crea la siguiente estructura en el directorio actual:

```
domjudge-docker/
├── docker-compose.yml
├── .env.example
├── judgehost/
│   └── Dockerfile              # extiende imagen oficial añadiendo Go
├── scripts/
│   ├── excel_to_tsv.py         # convierte Excel → accounts.tsv + teams.tsv
│   ├── backup_db.sh            # mysqldump del estado
│   └── restore_db.sh
├── problemas/
│   └── ejemplo-suma/           # problema de ejemplo completo
│       ├── problem.yaml
│       ├── domjudge-problem.ini
│       ├── problem_statement/
│       │   └── problem.tex
│       ├── data/
│       │   ├── sample/
│       │   │   ├── 1.in
│       │   │   └── 1.ans
│       │   └── secret/
│       │       ├── 1.in
│       │       ├── 1.ans
│       │       ├── 2.in
│       │       └── 2.ans
│       └── submissions/
│           ├── accepted/
│           │   ├── sol.go
│           │   └── sol.py
│           └── wrong_answer/
│               └── wa.py
├── usuarios/
│   ├── estudiantes.example.xlsx     # plantilla de Excel
│   └── README.md                    # explica formato de columnas
└── README.md                        # instrucciones de uso end-to-end
```

### Tarea 2 — `docker-compose.yml`

Tres servicios: `mariadb`, `domserver`, `judgehost-0`. Variables sensibles desde `.env`. Volumen persistente para la BD. Puerto `12345:80` para domserver. El judgehost en modo `privileged` (necesario para cgroups y chroot) y dependiente del domserver.

Estructura mínima esperada:

```yaml
services:
  mariadb:
    image: mariadb:11
    command: --max-connections=1000 --innodb-log-file-size=128M
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_USER: domjudge
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      MYSQL_DATABASE: domjudge
    volumes:
      - db:/var/lib/mysql
    restart: unless-stopped

  domserver:
    image: domjudge/domserver:latest
    depends_on: [mariadb]
    environment:
      MYSQL_HOST: mariadb
      MYSQL_USER: domjudge
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      MYSQL_DATABASE: domjudge
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    ports:
      - "12345:80"
    restart: unless-stopped

  judgehost-0:
    build: ./judgehost
    privileged: true
    hostname: judgehost-0
    depends_on: [domserver]
    environment:
      DAEMON_ID: 0
      JUDGEDAEMON_PASSWORD: ${JUDGEDAEMON_PASSWORD}
      DOMSERVER_BASEURL: http://domserver/
    links: [domserver]
    restart: unless-stopped

volumes:
  db:
```

Y `.env.example`:

```
MYSQL_ROOT_PASSWORD=cambia-esto-root
MYSQL_PASSWORD=cambia-esto-domjudge
JUDGEDAEMON_PASSWORD=  # se obtiene tras primer arranque del domserver
```

### Tarea 3 — `judgehost/Dockerfile`

Extiende `domjudge/judgehost:latest` añadiendo Go. Python 3 ya está incluido. Asegura que `go` quede en el PATH del usuario `domjudge-run`.

```dockerfile
FROM domjudge/judgehost:latest

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
        golang-go \
        ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && go version

# Cache de módulos Go en una ruta accesible (deshabilitar fetch online en sandbox)
ENV GOCACHE=/tmp/.gocache \
    GOPATH=/tmp/.gopath \
    GOFLAGS=-mod=vendor

USER domjudge
```

### Tarea 4 — Script `scripts/excel_to_tsv.py`

Convierte un `.xlsx` a los TSVs que DOMjudge espera (`accounts.tsv` y `teams.tsv`).

Requisitos:
- Lee `usuarios/estudiantes.xlsx` (ruta como argumento CLI, default `usuarios/estudiantes.xlsx`).
- Columnas obligatorias: `username`, `password`, `nombre_completo`. Opcional: `grupo` (default group_id `3` = "Participants").
- Genera `usuarios/accounts.tsv` y `usuarios/teams.tsv` con el formato DOMjudge v8+:
  - `accounts.tsv` cabecera: `accounts\t1`
  - `teams.tsv` cabecera: `File_Version\t1`
- Valida que no haya usernames duplicados ni campos vacíos. Reporta errores con `sys.exit(1)`.
- Imprime un resumen (`N usuarios procesados → accounts.tsv, teams.tsv`).
- Dependencias: `pandas`, `openpyxl`. Incluye comentario con `pip install pandas openpyxl`.

### Tarea 5 — Problema de ejemplo `problemas/ejemplo-suma/`

Problema trivial "Sumar dos enteros" que sirva para validar que el sandbox funciona en ambos lenguajes.

- `problem.yaml`:
  ```yaml
  name: Suma de dos enteros
  validation: default
  limits:
      memory: 256
  ```
- `domjudge-problem.ini`:
  ```
  timelimit = 1
  ```
- `problem_statement/problem.tex`: enunciado breve en LaTeX. Si LaTeX es demasiado, sustituir por `problem.md` con el enunciado en Markdown.
- `data/sample/1.in` → `2 3`
- `data/sample/1.ans` → `5`
- `data/secret/1.in` → `100 200` ; `1.ans` → `300`
- `data/secret/2.in` → `-5 5` ; `2.ans` → `0`
- `submissions/accepted/sol.go`: solución correcta en Go.
- `submissions/accepted/sol.py`: solución correcta en Python.
- `submissions/wrong_answer/wa.py`: solución que sume mal a propósito (para validar que el juez detecta WA).

Genera además un script `problemas/empaquetar.sh` que produzca el ZIP listo para subir:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/ejemplo-suma"
zip -r ../ejemplo-suma.zip . -x "*.DS_Store"
echo "Generado: problemas/ejemplo-suma.zip"
```

### Tarea 6 — Backup y restore

`scripts/backup_db.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
TS=$(date +%Y%m%d-%H%M%S)
mkdir -p backups
docker compose exec -T mariadb \
  mysqldump -u root -p"${MYSQL_ROOT_PASSWORD:?define en .env}" domjudge \
  > "backups/domjudge-${TS}.sql"
echo "Backup en backups/domjudge-${TS}.sql"
```

`scripts/restore_db.sh` toma un archivo `.sql` como argumento y lo restaura.

### Tarea 7 — `README.md` raíz

Documenta el flujo end-to-end:

1. **Pre-requisitos**: Docker Desktop / Docker Engine + Compose v2.
2. **Primer arranque**:
   ```bash
   cp .env.example .env
   # editar .env con passwords seguros
   docker compose up -d mariadb domserver
   docker compose logs domserver | grep -i "initial admin password"
   ```
   Anota el password admin.
3. **Obtener el `JUDGEDAEMON_PASSWORD`**:
   ```bash
   docker compose exec domserver cat /opt/domjudge/domserver/etc/restapi.secret
   ```
   Pega el valor en `.env` y reinicia.
4. **Levantar el judgehost**:
   ```bash
   docker compose up -d --build judgehost-0
   ```
5. **Habilitar lenguajes**: Admin → Languages → activa `python3` y `go`. Verifica memoria 512+ MB para Go.
6. **Crear concurso**: Jury → Contests → New. Define `start`, `end`, `freeze`.
7. **Subir problema de ejemplo**:
   ```bash
   bash problemas/empaquetar.sh
   ```
   Luego en Jury → Problems → Add → selecciona `problemas/ejemplo-suma.zip`.
8. **Importar estudiantes**:
   ```bash
   pip install pandas openpyxl
   python scripts/excel_to_tsv.py usuarios/estudiantes.xlsx
   ```
   Luego Jury → Import / Export → sube `accounts.tsv` y `teams.tsv`.
9. **Verificar sandbox**: ingresa como un equipo de prueba, envía `submissions/accepted/sol.go` al problema → debe dar **AC**. Repite con `wa.py` → debe dar **WA**.
10. **Backup**:
    ```bash
    bash scripts/backup_db.sh
    ```

Incluye una sección **Troubleshooting** con los 5 errores más comunes:
- Judgehost queda en estado "no judgings" → revisar `JUDGEDAEMON_PASSWORD`.
- TLE inesperado en Go → subir memoria del lenguaje a 512 MB.
- Error 500 al subir ZIP → verificar `problem.yaml` y permisos de `data/`.
- "Cannot connect to MySQL" → esperar a que mariadb termine de inicializar (~30s primer arranque).
- Cgroups v2 incompatibles → en kernels recientes añadir `systemd.unified_cgroup_hierarchy=0` al host o usar imagen judgehost ≥ 8.3.

### Tarea 8 — `usuarios/README.md`

Explica el formato del Excel:

| username | password | nombre_completo  | grupo |
|----------|----------|------------------|-------|
| est001   | abc123   | Juan Pérez       | 3     |
| est002   | xyz789   | María Gómez      | 3     |

- `username`: alfanumérico sin espacios, único.
- `password`: texto plano (DOMjudge la hashea al importar).
- `nombre_completo`: para mostrar en scoreboard.
- `grupo`: ID numérico del grupo en DOMjudge (default `3` = Participants). Crea grupos personalizados primero en Admin → Groups si quieres separar secciones.

---

## Criterios de aceptación

- [ ] `docker compose up -d` deja los 3 servicios corriendo sin errores.
- [ ] El judgehost reporta como activo en Admin → Judgehosts.
- [ ] Tanto `sol.go` como `sol.py` dan veredicto **AC** en el problema de ejemplo.
- [ ] `wa.py` da veredicto **WA**.
- [ ] La importación de un Excel con 5 estudiantes crea las 5 cuentas que pueden iniciar sesión.
- [ ] Un concurso configurado con `end = ahora + 5 min` rechaza envíos pasados los 5 minutos.
- [ ] `scripts/backup_db.sh` produce un `.sql` válido y restaurable.

---

## No-objetivos

- HTTPS / reverse proxy (Caddy/Traefik): se añadirá en una fase posterior.
- Múltiples judgehosts (escalado horizontal): documentar cómo pero no levantar más de uno.
- Validators custom: el problema de ejemplo usa `default` (diff exacto).
- Integración LDAP/SSO.

---

## Notas técnicas para el agente

- Usa **imágenes oficiales** de DOMjudge, no construyas el domserver desde fuente.
- El `JUDGEDAEMON_PASSWORD` **no se conoce hasta el primer arranque** del domserver. El README debe dejar este paso clarísimo (es el error #1 al desplegar DOMjudge en Docker).
- En Windows con Docker Desktop, el modo `privileged` del judgehost funciona pero los cgroups pueden requerir WSL2 con kernel reciente.
- Si la versión de DOMjudge cambia el formato de import (de TSV a JSON/YAML en v9+), ajusta `excel_to_tsv.py` para emitir también `accounts.yaml`.
- No incluyas passwords reales en ningún archivo versionado. Añade `.env`, `usuarios/estudiantes.xlsx` y `backups/` al `.gitignore`.

---

**Empieza creando la estructura de carpetas, luego el `docker-compose.yml`, después el resto en el orden listado. Al finalizar, ejecuta `docker compose config` para validar la sintaxis del compose.**
