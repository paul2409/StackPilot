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
            CREATE TABLE IF NOT EXISTS balances (
                id SERIAL PRIMARY KEY,
                username TEXT UNIQUE NOT NULL,
                currency TEXT NOT NULL,
                amount NUMERIC(12,2) NOT NULL
            );
            """
        )

        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS transactions (
                id SERIAL PRIMARY KEY,
                username TEXT NOT NULL,
                type TEXT NOT NULL,
                amount NUMERIC(12,2) NOT NULL,
                currency TEXT NOT NULL,
                description TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            """
        )

        cur.execute(
            """
            INSERT INTO balances (username, currency, amount)
            VALUES
                ('customer1', 'USD', 1200.00),
                ('customer2', 'USD', 850.00)
            ON CONFLICT (username) DO NOTHING;
            """
        )

        cur.execute(
            """
            INSERT INTO transactions (username, type, amount, currency, description)
            VALUES
                ('customer1', 'credit', 500.00, 'USD', 'Initial deposit'),
                ('customer1', 'debit', 120.00, 'USD', 'Card payment'),
                ('customer2', 'credit', 300.00, 'USD', 'Wallet topup');
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