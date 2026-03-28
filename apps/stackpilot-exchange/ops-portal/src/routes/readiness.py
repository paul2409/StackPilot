from fastapi import APIRouter

from src.clients import identity_client, wallet_client, system_client

router = APIRouter()


@router.get("/ready")
def ready():
    dependencies = {
        "identity-service": "unknown",
        "wallet-service": "unknown",
        "system-service": "unknown",
    }

    all_ready = True

    try:
        identity = identity_client.ready()
        dependencies["identity-service"] = identity.get("status", "unknown")
        if identity.get("status") != "ready":
            all_ready = False
    except Exception:
        dependencies["identity-service"] = "down"
        all_ready = False

    try:
        wallet = wallet_client.ready()
        dependencies["wallet-service"] = wallet.get("status", "unknown")
        if wallet.get("status") != "ready":
            all_ready = False
    except Exception:
        dependencies["wallet-service"] = "down"
        all_ready = False

    try:
        system = system_client.ready()
        dependencies["system-service"] = system.get("status", "unknown")
        if system.get("status") != "ready":
            all_ready = False
    except Exception:
        dependencies["system-service"] = "down"
        all_ready = False

    return {
        "status": "ready" if all_ready else "not_ready",
        "service": "ops-portal",
        "dependencies": dependencies,
    }