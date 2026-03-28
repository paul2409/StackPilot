from contextlib import contextmanager
import psycopg2
from psycopg2.extras import RealDictCursor

from src.config import DATABASE_URL


def get_connection():
    return psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)


@contextmanager
def get_cursor(commit: bool = False):
    conn = get_connection()
    try:
        cur = conn.cursor()
        yield cur
        if commit:
            conn.commit()
    finally:
        conn.close()


def init_db():
    with get_cursor(commit=True) as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                username TEXT UNIQUE NOT NULL,
                full_name TEXT NOT NULL,
                role TEXT NOT NULL,
                token TEXT NOT NULL
            );
            """
        )

        cur.execute(
            """
            INSERT INTO users (username, full_name, role, token)
            VALUES
                ('customer1', 'Customer One', 'customer', 'token-customer1'),
                ('admin1', 'Admin One', 'admin', 'token-admin1')
            ON CONFLICT (username) DO NOTHING;
            """
        )


def ping_db() -> bool:
    try:
        with get_cursor() as cur:
            cur.execute("SELECT 1;")
            cur.fetchone()
        return True
    except Exception:
        return False