import os

SERVICE_NAME = os.getenv("SERVICE_NAME", "wallet-service")
SERVICE_VERSION = os.getenv("SERVICE_VERSION", "1.0.0")
ENV = os.getenv("ENV", "dev")
BUILD_TIME = os.getenv("BUILD_TIME", "unknown")
GIT_SHA = os.getenv("GIT_SHA", SERVICE_VERSION)
PORT = int(os.getenv("PORT", "8000"))

POSTGRES_HOST = os.getenv("POSTGRES_HOST", "postgres-wallet")
POSTGRES_PORT = int(os.getenv("POSTGRES_PORT", "5432"))
POSTGRES_DB = os.getenv("POSTGRES_DB", "wallet_db")
POSTGRES_USER = os.getenv("POSTGRES_USER", "wallet_user")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "wallet_pass")

DATABASE_URL = (
    f"postgresql://{POSTGRES_USER}:{POSTGRES_PASSWORD}"
    f"@{POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_DB}"
)