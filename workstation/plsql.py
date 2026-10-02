#!/usr/bin/env python3
"""Ejecuta SQL o PL/SQL contra Oracle con python-oracledb en modo thin."""

from __future__ import annotations

import os
import sys

import oracledb

SQLPLUS_PREFIXES = (
    "SET ",
    "PROMPT",
    "SPOOL",
    "WHENEVER",
    "DEFINE",
    "COLUMN",
    "TTITLE",
    "BTITLE",
    "REPHEADER",
    "REPFOOTER",
    "CLEAR",
    "BREAK",
    "COMPUTE",
    "ACCEPT",
    "PAUSE",
    "HOST",
    "CONNECT",
    "CONN ",
    "REM",
    "--",
)


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def load_source() -> str:
    if len(sys.argv) > 2:
        fail("Uso: plsql [archivo.sql | -]")
    if len(sys.argv) == 1 or sys.argv[1] == "-":
        return sys.stdin.read()
    path = sys.argv[1]
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except OSError as exc:
        fail(f"No se pudo leer {path}: {exc}")
    return ""


def prepare(script: str) -> tuple[list[str], bool]:
    serveroutput = False
    kept: list[str] = []
    for raw in script.splitlines():
        stripped = raw.strip()
        upper = stripped.upper()
        if upper.startswith("SET SERVEROUTPUT"):
            serveroutput = "ON" in upper
            continue
        if upper in {"EXIT", "EXIT;", "QUIT", "QUIT;"}:
            continue
        if stripped and upper.startswith(SQLPLUS_PREFIXES):
            continue
        kept.append(raw)

    chunks: list[str] = []
    buffer: list[str] = []
    for raw in kept:
        if raw.strip() == "/":
            statement = normalize("\n".join(buffer))
            if statement:
                chunks.append(statement)
            buffer = []
            continue
        buffer.append(raw)
    tail = normalize("\n".join(buffer))
    if tail:
        chunks.append(tail)
    return chunks, serveroutput


def normalize(statement: str) -> str:
    text = statement.strip()
    if not text:
        return ""
    head = text.lstrip().upper()
    if head.startswith(("DECLARE", "BEGIN", "CREATE")):
        return text
    return text.rstrip().rstrip(";").strip()


def print_serveroutput(cursor: oracledb.Cursor) -> None:
    line = cursor.var(oracledb.STRING)
    status = cursor.var(oracledb.NUMBER)
    while True:
        cursor.callproc("dbms_output.get_line", (line, status))
        if status.getvalue() != 0:
            break
        print(line.getvalue())


def main() -> None:
    user = os.environ.get("ORACLE_USER", "")
    password = os.environ.get("ORACLE_PASSWORD", "")
    dsn = os.environ.get("ORACLE_DSN", "")
    if not user or not password or not dsn:
        fail("Faltan ORACLE_USER, ORACLE_PASSWORD u ORACLE_DSN.")
    if password.startswith("cambia-esta-clave"):
        fail("ORACLE_PASSWORD sigue siendo el placeholder. Edita .env.")

    chunks, serveroutput = prepare(load_source())
    if not chunks:
        fail("El script no tiene sentencias ejecutables.")

    try:
        connection = oracledb.connect(user=user, password=password, dsn=dsn)
    except oracledb.Error as exc:
        fail(f"No se pudo conectar a {dsn}: {exc}")
        return

    with connection:
        cursor = connection.cursor()
        if serveroutput:
            cursor.callproc("dbms_output.enable")
        for statement in chunks:
            try:
                cursor.execute(statement)
            except oracledb.Error as exc:
                fail(f"Error ejecutando:\n{statement}\n{exc}")
            if cursor.description:
                columns = [item[0] for item in cursor.description]
                print("\t".join(columns))
                for row in cursor:
                    print("\t".join("" if value is None else str(value) for value in row))
            else:
                affected = cursor.rowcount if cursor.rowcount is not None else 0
                print(f"OK ({affected} filas)")
        if serveroutput:
            print_serveroutput(cursor)
        connection.commit()


if __name__ == "__main__":
    main()
