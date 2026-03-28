from fastapi import APIRouter

from src.clients import identity_client, wallet_client

router = APIRouter()


@router.get("/ready")
def ready():
    results = {
        "identity-service": "unknown",
        "wallet-service": "unknown",
    }

    all_ready = True

    try:
        identity_ready = identity_client.get_ready()
        results["identity-service"] = identity_ready.get("status", "unknown")
        if identity_ready.get("status") != "ready":
            all_ready = False
    except Exception:
        results["identity-service"] = "down"
        all_ready = False

    try:
        wallet_ready = wallet_client.get_ready()
        results["wallet-service"] = wallet_ready.get("status", "unknown")
        if wallet_ready.get("status") != "ready":
            all_ready = False
    except Exception:
        results["wallet-service"] = "down"
        all_ready = False

    return {
        "status": "ready" if all_ready else "not_ready",
        "service": "system-service",
        "dependencies": results,
    }