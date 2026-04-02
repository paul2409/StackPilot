from prometheus_client import Counter, Gauge, Info
from prometheus_fastapi_instrumentator import Instrumentator

from src.config import BUILD_TIME, ENV, GIT_SHA, SERVICE_NAME, SERVICE_VERSION

WALLET_DB_CHECK_FAILURES = Counter(
    "wallet_db_check_failures_total",
    "Wallet DB readiness check failures",
)
WALLET_DEPENDENCY_STATE = Gauge(
    "wallet_dependency_state",
    "Wallet dependency availability",
    ["dependency"],
)
DEPENDENCY_CHECK_FAILURES = Counter(
    "dependency_check_failures_total",
    "Dependency check failures",
    ["dependency"],
)
SERVICE_READY_STATE = Gauge(
    "service_ready_state",
    "Service readiness state",
    ["service", "environment"],
)
SERVICE_BUILD = Info(
    "service_build",
    "Service build metadata",
)
WALLET_TRANSFER_REQUESTS = Counter(
    "wallet_transfer_requests_total",
    "Wallet transfer requests",
)
WALLET_BALANCE_REQUESTS = Counter(
    "wallet_balance_requests_total",
    "Wallet balance requests",
)
WALLET_HISTORY_REQUESTS = Counter(
    "wallet_history_requests_total",
    "Wallet history requests",
)

def configure_metrics(app):
    Instrumentator(
        should_group_status_codes=False,
        should_ignore_untemplated=False,
        excluded_handlers=["/metrics"],
        env_var_name="ENABLE_METRICS",
        inprogress=True,
    ).instrument(app).expose(app, include_in_schema=False, endpoint="/metrics")
    SERVICE_BUILD.info(
        {
            "service": SERVICE_NAME,
            "version": SERVICE_VERSION,
            "environment": ENV,
            "git_sha": GIT_SHA,
            "build_time": BUILD_TIME,
        }
    )
    SERVICE_READY_STATE.labels(service=SERVICE_NAME, environment=ENV).set(0)
    WALLET_DEPENDENCY_STATE.labels(dependency="postgres-wallet").set(1)

def mark_ready(is_ready: bool):
    SERVICE_READY_STATE.labels(service=SERVICE_NAME, environment=ENV).set(1 if is_ready else 0)

def record_wallet_db_failure():
    WALLET_DB_CHECK_FAILURES.inc()
    DEPENDENCY_CHECK_FAILURES.labels(dependency="postgres-wallet").inc()
    WALLET_DEPENDENCY_STATE.labels(dependency="postgres-wallet").set(0)

def record_wallet_db_ok():
    WALLET_DEPENDENCY_STATE.labels(dependency="postgres-wallet").set(1)

def record_balance_request():
    WALLET_BALANCE_REQUESTS.inc()

def record_history_request():
    WALLET_HISTORY_REQUESTS.inc()

def record_transfer_request():
    WALLET_TRANSFER_REQUESTS.inc()
