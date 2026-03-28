from fastapi import APIRouter

from src.clients import wallet_client, system_client

router = APIRouter()


@router.get("/health")
def health():
    return {"status": "ok", "service": "admin-portal"}


@router.get("/ready")
def ready():
    deps = {
        "wallet-service": "unknown",
        "system-service": "unknown",
    }
    all_ready = True

    try:
        w = wallet_client.ready()
        deps["wallet-service"] = w.get("status")
        if w.get("status") != "ready":
            all_ready = False
    except Exception:
        deps["wallet-service"] = "down"
        all_ready = False

    try:
        s = system_client.ready()
        deps["system-service"] = s.get("status")
        if s.get("status") != "ready":
            all_ready = False
    except Exception:
        deps["system-service"] = "down"
        all_ready = False

    return {
        "status": "ready" if all_ready else "not_ready",
        "dependencies": deps,
    }