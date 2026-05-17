"""Postgres connection helpers."""
from __future__ import annotations

from contextlib import contextmanager

from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

from pipeline.config import DB_URL


def get_engine() -> Engine:
    return create_engine(DB_URL, future=True)


@contextmanager
def connection():
    engine = get_engine()
    with engine.connect() as conn:
        yield conn
        conn.commit()


def execute_sql_file(path: str) -> None:
    """Run a .sql file against the database."""
    with open(path, encoding="utf-8") as fh:
        sql = fh.read()
    with connection() as conn:
        conn.execute(text(sql))
