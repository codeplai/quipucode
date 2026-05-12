#!/usr/bin/env python3
# pip install pandas openpyxl

import sys
import os
import pandas as pd

DEFAULT_INPUT = os.path.join(os.path.dirname(__file__), "..", "usuarios", "estudiantes.xlsx")
DEFAULT_OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "usuarios")

REQUIRED_COLS = {"username", "password", "nombre_completo"}
DEFAULT_GROUP_ID = 3


def load_excel(path: str) -> pd.DataFrame:
    try:
        df = pd.read_excel(path, dtype=str)
    except FileNotFoundError:
        print(f"ERROR: No se encontró el archivo '{path}'", file=sys.stderr)
        sys.exit(1)

    df.columns = [c.strip().lower() for c in df.columns]
    missing = REQUIRED_COLS - set(df.columns)
    if missing:
        print(f"ERROR: Columnas faltantes en el Excel: {missing}", file=sys.stderr)
        sys.exit(1)

    return df


def validate(df: pd.DataFrame) -> None:
    errors = []

    for col in REQUIRED_COLS:
        blanks = df[df[col].isna() | (df[col].str.strip() == "")].index.tolist()
        if blanks:
            errors.append(f"Columna '{col}' vacía en filas: {[i+2 for i in blanks]}")

    dups = df[df["username"].duplicated(keep=False)]["username"].unique().tolist()
    if dups:
        errors.append(f"Usernames duplicados: {dups}")

    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)


def write_accounts_tsv(df: pd.DataFrame, out_dir: str) -> None:
    path = os.path.join(out_dir, "accounts.tsv")
    with open(path, "w", encoding="utf-8") as f:
        f.write("accounts\t1\n")
        for _, row in df.iterrows():
            # DOMjudge accounts.tsv real format (ImportExportService.php):
            #   line[0]=type  line[1]=fullname  line[2]=username  line[3]=password
            # DOMjudge extracts the team ID from the username via regex
            # (strips leading non-digits and leading zeros, e.g. est001 → 1)
            # and finds the team whose externalid equals that number.
            f.write(f"team\t{row['nombre_completo'].strip()}\t{row['username'].strip()}\t{row['password'].strip()}\n")
    print(f"  -> {path}")


def write_teams_tsv(df: pd.DataFrame, out_dir: str) -> None:
    path = os.path.join(out_dir, "teams.tsv")
    with open(path, "w", encoding="utf-8") as f:
        f.write("File_Version\t1\n")
        for i, row in enumerate(df.itertuples(index=False), start=1):
            group_id = getattr(row, "grupo", "").strip() if "grupo" in df.columns else ""
            group_id = group_id if group_id else str(DEFAULT_GROUP_ID)
            name = row.nombre_completo.strip()
            # id \t external_id \t group_id \t name \t members
            # external_id must be the same numeric value that DOMjudge extracts
            # from the username (est001 → 1, est002 → 2, etc.)
            f.write(f"{i}\t{i}\t{group_id}\t{name}\t\n")
    print(f"  -> {path}")


def main():
    input_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_INPUT
    out_dir = os.path.dirname(os.path.abspath(input_path))

    df = load_excel(input_path)
    validate(df)
    os.makedirs(out_dir, exist_ok=True)
    write_accounts_tsv(df, out_dir)
    write_teams_tsv(df, out_dir)
    print(f"\n{len(df)} usuarios procesados -> accounts.tsv, teams.tsv")


if __name__ == "__main__":
    main()
