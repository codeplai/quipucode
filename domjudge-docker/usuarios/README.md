# Formato del Excel de estudiantes

El archivo `estudiantes.xlsx` debe tener las siguientes columnas:

| username | password | nombre_completo  | grupo |
|----------|----------|------------------|-------|
| est001   | abc123   | Juan Pérez       | 3     |
| est002   | xyz789   | María Gómez      | 3     |

## Descripción de columnas

- **username** — Alfanumérico sin espacios, único por concurso. Ejemplo: `est001`.
- **password** — Texto plano. DOMjudge la hashea al importar. Mínimo 6 caracteres recomendado.
- **nombre_completo** — Nombre visible en el scoreboard. Puede contener espacios y tildes.
- **grupo** — (Opcional) ID numérico del grupo en DOMjudge. Default: `3` (Participants).
  Si quieres separar secciones (A, B, C), crea los grupos primero en **Admin → Groups**
  y usa el ID asignado por DOMjudge.

## Cómo generar los TSVs

```bash
pip install pandas openpyxl
python scripts/excel_to_tsv.py usuarios/estudiantes.xlsx
```

Esto produce:
- `usuarios/accounts.tsv` — para importar en **Jury → Import/Export → Accounts**
- `usuarios/teams.tsv`   — para importar en **Jury → Import/Export → Teams**

## Errores comunes

| Error | Causa |
|-------|-------|
| `Columnas faltantes` | El Excel no tiene las columnas requeridas o tienen tildes/mayúsculas distintas |
| `Usernames duplicados` | Dos filas con el mismo `username` |
| `campo vacío` | Alguna celda obligatoria está en blanco |
