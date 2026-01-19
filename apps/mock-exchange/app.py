# Standard library imports
import os          # Used to read environment variables (config contract)
import time        # Used for timestamps and latency measurement
import uuid        # Used to generate unique order IDs

# FastAPI imports
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse

# Create the FastAPI application object
# This represents the running service/process
app = FastAPI()

# -------------------------------------------------
# STRICT CONFIGURATION SECTION (CRITICAL)
# -------------------------------------------------

# These environment variables MUST exist.
# If any are missing, the service must refuse to start.
REQUIRED_ENV_VARS = [
    "SERVICE_NAME",
    "ENV",
    "LOG_LEVEL",
    "VERSION",
]

def load_config_or_die():
    """
    Load required configuration from environment variables.

    If any required variable is missing:
    - Raise an exception
    - Kill the process at startup
    - Prevent a half-broken service from running
    """
    missing = [k for k in REQUIRED_ENV_VARS if not os.getenv(k)]

    if missing:
        # Fail fast and loudly
        raise RuntimeError(
            f"Missing required env vars: {', '.join(missing)}"
        )

    # Return a dictionary containing runtime metadata
    # This is later exposed via /version
    return {
        "service": os.getenv("SERVICE_NAME"),
        "env": os.getenv("ENV"),
        "version": os.getenv("VERSION"),
        "log_level": os.getenv("LOG_LEVEL"),
        "git_sha": os.getenv("GIT_SHA", "unknown"),
        "build_time": os.getenv("BUILD_TIME", "unknown"),
    }

# Global config object
# This will be populated exactly once at startup
CONFIG = None

@app.on_event("startup")
def startup():
    """
    This function runs when the service starts.

    If config loading fails here:
    - FastAPI never finishes starting
    - The process exits
    - This is exactly what we want
    """
    global CONFIG
    CONFIG = load_config_or_die()

    # Log a startup event so operators know:
    # - which service started
    # - which version
    # - which environment
    log(
        "startup",
        service=CONFIG["service"],
        version=CONFIG["version"],
        env=CONFIG["env"],
        git_sha=CONFIG["git_sha"],
    )

# -------------------------------------------------
# STRUCTURED LOGGING (OPS-ORIENTED)
# -------------------------------------------------

def log(event, **fields):
    """
    Simple structured logger.

    Why this format?
    - Easy to read by humans
    - Easy to parse by machines
    - Easy to grep in production

    Example output:
    event='request' ts=1712345678 method='GET' path='/health'
    """
    base = {
        "event": event,
        "ts": int(time.time()),
    }

    # Merge extra fields into base log record
    base.update(fields)

    # Print as key=value pairs
    line = " ".join(f"{k}={repr(v)}" for k, v in base.items())
    print(line, flush=True)

@app.middleware("http")
async def request_logger(request: Request, call_next):
    """
    Middleware runs for EVERY HTTP request.

    Purpose:
    - Measure latency
    - Log request metadata
    - Log failures consistently
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
            error=str(e),
        )

        # Re-raise so FastAPI handles it properly
        raise

@app.exception_handler(Exception)
async def unhandled_exception(request: Request, exc: Exception):
    """
    Catch-all exception handler.

    Why?
    - Prevent ugly stack traces from leaking
    - Return predictable JSON errors
    - Make failures observable but controlled
    """
    return JSONResponse(
        status_code=500,
        content={
            "error": type(exc).__name__,
            "message": str(exc),
        },
    )

# -------------------------------------------------
# ENDPOINTS (SERVICE CONTRACT)
# -------------------------------------------------

@app.get("/health")
def health():
    """
    LIVENESS CHECK.

    Meaning:
    - Is the process running?
    - Nothing else.

    It should return 200 even if:
    - Database is down
    - Dependencies are broken
    """
    return {"ok": True}

@app.get("/ready")
def ready():
    """
    READINESS CHECK.

    Meaning:
    - Is the service ready to accept traffic?

    Day 9 rule:
    - Ready ONLY if config loaded
    """
    if CONFIG is None:
        raise HTTPException(status_code=503, detail="config_not_loaded")

    return {
        "ready": True,
        "checks": {"config_loaded": True},
    }

@app.get("/version")
def version():
    """
    Version and build metadata endpoint.

    This prevents:
    - Stale deploy confusion
    - "Which version is running?" guessing
    """
    if CONFIG is None:
        raise HTTPException(status_code=503, detail="config_not_loaded")

    return CONFIG

@app.get("/price")
def price(symbol: str):
    """
    Fake pricing endpoint.

    Deterministic on purpose.
    Randomness hides bugs.
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
    Create a fake order.

    This endpoint exists mainly to:
    - Generate logs
    - Exercise validation
    - Produce IDs for later DB work
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

    # Log a domain event
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
    Placeholder endpoint.

    Exists to:
    - Lock the API shape
    - Make Day 11 (DB) a drop-in replacement
    """
    return {
        "order_id": order_id,
        "status": "placeholder",
        "note": "DB comes Day 11",
    }
# End of file: apps/mock-exchange/app.py