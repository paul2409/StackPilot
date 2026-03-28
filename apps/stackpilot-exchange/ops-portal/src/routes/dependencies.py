from fastapi import APIRouter

from src.clients import identity_client, wallet_client, system_client

router = APIRouter()


def safe_ready(name: str, fn):
    try:
        data = fn()
        return {
            "service": name,
            "status": data.get("status", "unknown"),
            "ok": data.get("status") == "ready",
            "data": data,
        }
    except Exception as exc:
        return {
            "service": name,
            "status": "down",
            "ok": False,
            "error": str(exc),
        }


@router.get("/ops/dependencies")
def dependencies():
    return {
        "service": "ops-portal",
        "dependencies": {
            "identity-service": safe_ready("identity-service", identity_client.ready),
            "wallet-service": safe_ready("wallet-service", wallet_client.ready),
            "system-service": safe_ready("system-service", system_client.ready),
        },
    }