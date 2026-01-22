# =================================================
# apps/mock-exchange/app.py
# =================================================
#
# This file defines the mock-exchange API service.
#
# Design goals:
# - Fail fast on bad configuration
# - Separate liveness from readiness
# - Remain observable under dependency failure
# - Behave like a real production service, not a demo
#
# =================================================


# ----------------------------
# Standard library imports
# ----------------------------
import os          # Read environment variables (config contract)
import time        # Timestamps and latency measurement
import uuid        # Generate unique order IDs


# ----------------------------
# Third-party imports
# ----------------------------
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse

# PostgreSQL driver (Day 11 dependency)
import psycopg


# =================================================
# APPLICATION OBJECT
# =================================================
#
# This represents the running service process.
# If this object exists and responds, the process is alive.
#
app = FastAPI()


# =================================================
# STRICT CONFIGURATION CONTRACT (STARTUP)
# =================================================
#
# These variables MUST exist at startup.
# If any are missing, the service must refuse to start.
#
# This prevents:
# - half-configured deployments
# - silent misbehavior
# - debugging by guesswork
#

REQUIRED_ENV_VARS = [
    "SERVICE_NAME",
    "ENV",
    "LOG_LEVEL",
    "VERSION",
]


def load_config_or_die():
    """
    Load required runtime configuration.

    Behavior:
    - Validate required env vars
    - Kill the process immediately if any are missing

    This enforces a *hard startup contract*.
    """
    missing = [k for k in REQUIRED_ENV_VARS if not os.getenv(k)]

    if missing:
        raise RuntimeError(
            f"Missing required env vars: {', '.join(missing)}"
        )

    # Runtime metadata exposed via /version
    return {
        "service": os.getenv("SERVICE_NAME"),
        "env": os.getenv("ENV"),
        "version": os.getenv("VERSION"),
        "log_level": os.getenv("LOG_LEVEL"),
        "git_sha": os.getenv("GIT_SHA", "unknown"),
        "build_time": os.getenv("BUILD_TIME", "unknown"),
    }


# Global config is loaded exactly once at startup.
CONFIG = None


@app.on_event("startup")
def startup():
    """
    FastAPI startup hook.

    If config loading fails here:
    - The service never becomes available
    - Containers fail fast
    - Broken deployments are obvious
    """
    global CONFIG
    CONFIG = load_config_or_die()

    log(
        "startup",
        service=CONFIG["service"],
        version=CONFIG["version"],
        env=CONFIG["env"],
        git_sha=CONFIG["git_sha"],
    )


# =================================================
# STRUCTURED LOGGING (OPS-ORIENTED)
# =================================================
#
# Logs are:
# - line-oriented
# - key=value formatted
# - safe to grep
# - safe to parse
#

def log(event, **fields):
    """
    Emit a structured log line.

    Example:
    event='request' ts=1712345678 method='GET' path='/health'
    """
    record = {
        "event": event,
        "ts": int(time.time()),
    }
    record.update(fields)

    line = " ".join(f"{k}={repr(v)}" for k, v in record.items())
    print(line, flush=True)


@app.middleware("http")
async def request_logger(request: Request, call_next):
    """
    Global request middleware.

    Responsibilities:
    - Measure latency
    - Log request metadata
    - Ensure failures are observable
    """
    start = time.time()

    try:
        response = await call_next(request)
        latency_ms = int((time.time() - start) * 1000)

        log(
            "request",
            method=request.method,
            path=request.url.path,
            status=response.status_code,
            latency_ms=latency_ms,
        )

        return response

    except Exception as e:
        latency_ms = int((time.time() - start) * 1000)

        log(
            "error",
            method=request.method,
            path=request.url.path,
            latency_ms=latency_ms,
            error=type(e).__name__,
        )
        raise


@app.exception_handler(Exception)
async def unhandled_exception(request: Request, exc: Exception):
    """
    Final safety net.

    Prevents raw stack traces from leaking to clients
    while keeping errors observable via logs.
    """
    return JSONResponse(
        status_code=500,
        content={
            "error": type(exc).__name__,
            "message": str(exc),
        },
    )


# =================================================
# DATABASE HELPERS 
# =================================================
#
# DB is treated as an external dependency:
# - networked
# - fallible
# - not required for process liveness
#

DB_REQUIRED_VARS = ["DB_HOST", "DB_NAME", "DB_USER", "DB_PASSWORD"]


def db_dsn_or_empty() -> str:
    """
    Build a PostgreSQL DSN from env vars.

    Returns:
    - DSN string if config exists
    - empty string if config is missing
    """
    missing = [k for k in DB_REQUIRED_VARS if not os.getenv(k)]
    if missing:
        return ""

    return (
        f"host={os.getenv('DB_HOST')} "
        f"port={os.getenv('DB_PORT', '5432')} "
        f"dbname={os.getenv('DB_NAME')} "
        f"user={os.getenv('DB_USER')} "
        f"password={os.getenv('DB_PASSWORD')} "
        f"connect_timeout=2"
    )


def db_ping() -> tuple[bool, str]:
    """
    Lightweight DB readiness probe.

    Used ONLY by /ready.
    """
    dsn = db_dsn_or_empty()
    if not dsn:
        return False, "db_config_missing"

    try:
        with psycopg.connect(dsn) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1;")
                cur.fetchone()
        return True, "ok"
    except Exception as e:
        return False, f"db_unreachable:{type(e).__name__}"


def db_connect():
    """
    Create a DB connection for request handlers.

    Raises HTTP 503 if DB is unavailable.
    """
    dsn = db_dsn_or_empty()
    if not dsn:
        raise HTTPException(status_code=503, detail="db_config_missing")

    try:
        return psycopg.connect(dsn)
    except Exception:
        log("db_connect_failed")
        raise HTTPException(status_code=503, detail="db_unreachable")


# =================================================
# SERVICE ENDPOINTS
# =================================================

@app.get("/health")
def health():
    """
    LIVENESS PROBE.

    Meaning:
    - Is the process alive?

    Must remain 200 even if:
    - Database is down
    - Dependencies are broken
    """
    return {"ok": True}


@app.get("/ready")
def ready():
    """
    READINESS PROBE.

    Meaning:
    - Is the service safe to receive traffic *right now*?

    Conditions:
    - Config loaded
    - DB reachable
    """
    if CONFIG is None:
        raise HTTPException(status_code=503, detail="config_not_loaded")

    ok, reason = db_ping()
    if not ok:
        raise HTTPException(status_code=503, detail=reason)

    return {
        "ready": True,
        "checks": {"config_loaded": True, "db": True},
    }


@app.get("/version")
def version():
    """
    Build and runtime metadata.

    Prevents stale-deploy confusion.
    """
    if CONFIG is None:
        raise HTTPException(status_code=503, detail="config_not_loaded")
    return CONFIG


@app.get("/price")
def price(symbol: str):
    """
    Deterministic pricing endpoint.

    No randomness by design.
    """
    symbol = symbol.upper()

    prices = {
        "BTC": 52000.0,
        "ETH": 3100.0,
    }

    if symbol not in prices:
        raise HTTPException(status_code=400, detail="unsupported_symbol")

    return {"symbol": symbol, "price": prices[symbol]}


@app.post("/order")
def create_order(symbol: str, side: str, qty: float):
    """
    Create and persist an order.

    Dependency behavior:
    - DB down → 503
    - Validation errors → 400
    """
    symbol = symbol.upper()
    side = side.lower()

    if symbol not in ["BTC", "ETH"]:
        raise HTTPException(status_code=400, detail="unsupported_symbol")

    if side not in ["buy", "sell"]:
        raise HTTPException(status_code=400, detail="invalid_side")

    if qty <= 0:
        raise HTTPException(status_code=400, detail="invalid_qty")

    order_id = str(uuid.uuid4())

    with db_connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO orders (id, symbol, side, qty, status)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (order_id, symbol, side, qty, "accepted"),
            )
        conn.commit()

    log(
        "order_created",
        order_id=order_id,
        symbol=symbol,
        side=side,
        qty=qty,
    )

    return {"order_id": order_id, "status": "accepted"}


@app.get("/orders/{order_id}")
def get_order(order_id: str):
    """
    Fetch an order from the database.

    Dependency behavior:
    - DB down → 503
    - Order missing → 404
    """
    with db_connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, symbol, side, qty, status, created_at
                FROM orders
                WHERE id = %s
                """,
                (order_id,),
            )
            row = cur.fetchone()

    if not row:
        raise HTTPException(status_code=404, detail="order_not_found")

    return {
        "order_id": row[0],
        "symbol": row[1],
        "side": row[2],
        "qty": float(row[3]),
        "status": row[4],
        "created_at": row[5].isoformat() if row[5] else None,
    }


# =================================================
# END OF FILE
# =================================================
