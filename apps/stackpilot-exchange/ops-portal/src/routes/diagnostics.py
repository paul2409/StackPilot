from fastapi import APIRouter

from src.clients import identity_client, wallet_client, system_client

router = APIRouter()


def safe_call(fn):
    try:
        return {
            "ok": True,
            "data": fn(),
        }
    except Exception as exc:
        return {
            "ok": False,
            "error": str(exc),
        }


@router.get("/ops/diagnostics")
def diagnostics():
    return {
        "service": "ops-portal",
        "diagnostics": {
            "identity-service": {
                "health": safe_call(identity_client.health),
                "ready": safe_call(identity_client.ready),
                "version": safe_call(identity_client.version),
            },
            "wallet-service": {
                "health": safe_call(wallet_client.health),
                "ready": safe_call(wallet_client.ready),
                "version": safe_call(wallet_client.version),
            },
            "system-service": {
                "health": safe_call(system_client.health),
                "ready": safe_call(system_client.ready),
                "version": safe_call(system_client.version),
                "status": safe_call(system_client.status),
            },
        },
    }