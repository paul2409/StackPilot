import os

SERVICE_NAME = os.getenv("SERVICE_NAME", "admin-portal")
SERVICE_VERSION = os.getenv("SERVICE_VERSION", "1.0.0")
ENV = os.getenv("ENV", "dev")
BUILD_TIME = os.getenv("BUILD_TIME", "unknown")
GIT_SHA = os.getenv("GIT_SHA", SERVICE_VERSION)
PORT = int(os.getenv("PORT", "8000"))

IDENTITY_SERVICE_URL = os.getenv("IDENTITY_SERVICE_URL", "http://identity-service:8000")
WALLET_SERVICE_URL = os.getenv("WALLET_SERVICE_URL", "http://wallet-service:8000")
SYSTEM_SERVICE_URL = os.getenv("SYSTEM_SERVICE_URL", "http://system-service:8000")

REQUEST_TIMEOUT = float(os.getenv("REQUEST_TIMEOUT", "2.0"))