from prometheus_client import Counter, Gauge, Info
from prometheus_fastapi_instrumentator import Instrumentator

from src.config import BUILD_TIME, ENV, GIT_SHA, SERVICE_NAME, SERVICE_VERSION

IDENTITY_DB_CHECK_FAILURES = Counter(
    "identity_db_check_failures_total",
    "Identity DB readiness check failures",
)
IDENTITY_LOGIN_REQUESTS = Counter(
    "identity_login_requests_total",
    "Identity login requests",
)
IDENTITY_LOOKUP_REQUESTS = Counter(
    "identity_lookup_requests_total",
    "Identity lookup requests",
    ["route"],
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

def mark_ready(is_ready: bool):
    SERVICE_READY_STATE.labels(service=SERVICE_NAME, environment=ENV).set(1 if is_ready else 0)

def record_identity_db_failure():
    IDENTITY_DB_CHECK_FAILURES.inc()
    DEPENDENCY_CHECK_FAILURES.labels(dependency="postgres-identity").inc()

def record_login_request():
    IDENTITY_LOGIN_REQUESTS.inc()

def record_lookup_request(route: str):
    IDENTITY_LOOKUP_REQUESTS.labels(route=route).inc()
