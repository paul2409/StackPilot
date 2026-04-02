from fastapi import APIRouter
from src.clients import identity_client, wallet_client
from src.observability import mark_ready, record_dependency_unready

router = APIRouter()


@router.get("/health")
def health():
    return {"status": "ok", "service": "customer-portal"}


@router.get("/ready")
def ready():
    deps = {"identity-service": "unknown", "wallet-service": "unknown"}
    all_ready = True

    try:
        i = identity_client.ready()
        deps["identity-service"] = i.get("status")
        if i.get("status") != "ready":
            record_dependency_unready("identity-service")
            all_ready = False
    except Exception:
        deps["identity-service"] = "down"
        record_dependency_unready("identity-service")
        all_ready = False

    try:
        w = wallet_client.ready()
        deps["wallet-service"] = w.get("status")
        if w.get("status") != "ready":
            record_dependency_unready("wallet-service")
            all_ready = False
    except Exception:
        deps["wallet-service"] = "down"
        record_dependency_unready("wallet-service")
        all_ready = False

    mark_ready(all_ready)
    return {
        "status": "ready" if all_ready else "not_ready",
        "service": "customer-portal",
        "dependencies": deps,
    }
