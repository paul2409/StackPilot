from fastapi import APIRouter

from src.clients import identity_client, wallet_client
from src.observability import record_summary_request

router = APIRouter()


def safe_call(fn):
    try:
        return {"ok": True, "data": fn()}
    except Exception as exc:
        return {"ok": False, "error": str(exc)}


@router.get("/status")
def status():
    record_summary_request()
    identity_health = safe_call(identity_client.get_health)
    identity_ready = safe_call(identity_client.get_ready)
    identity_version = safe_call(identity_client.get_version)

    wallet_health = safe_call(wallet_client.get_health)
    wallet_ready = safe_call(wallet_client.get_ready)
    wallet_version = safe_call(wallet_client.get_version)

    return {
        "service": "system-service",
        "dependencies": {
            "identity-service": {
                "health": identity_health,
                "ready": identity_ready,
                "version": identity_version,
            },
            "wallet-service": {
                "health": wallet_health,
                "ready": wallet_ready,
                "version": wallet_version,
            },
        },
    }