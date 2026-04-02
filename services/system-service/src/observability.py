from prometheus_client import Counter, Gauge, Info
from prometheus_fastapi_instrumentator import Instrumentator

from src.config import BUILD_TIME, ENV, GIT_SHA, SERVICE_NAME, SERVICE_VERSION

DEPENDENCY_CHECK_FAILURES = Counter(
    "dependency_check_failures_total",
    "Dependency check failures",
    ["dependency"],
)
SYSTEM_DEPENDENCY_UNREADY = Counter(
    "system_dependency_unready_total",
    "System service dependency failures",
    ["dependency"],
)
SYSTEM_SUMMARY_REQUESTS = Counter(
    "system_summary_requests_total",
    "System summary requests",
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

def record_dependency_unready(dependency: str):
    DEPENDENCY_CHECK_FAILURES.labels(dependency=dependency).inc()
    SYSTEM_DEPENDENCY_UNREADY.labels(dependency=dependency).inc()

def record_summary_request():
    SYSTEM_SUMMARY_REQUESTS.inc()
