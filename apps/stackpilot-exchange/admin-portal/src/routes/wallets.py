from fastapi import APIRouter, HTTPException

from src.clients import wallet_client
from src.models.responses import degraded_response
from src.observability import record_dependency_unready

router = APIRouter()


@router.get("/api/admin/wallets")
def wallets():
    try:
        user1 = wallet_client.balances("customer1")
        user2 = wallet_client.balances("customer2")

        return {
            "portal": "admin-portal",
            "wallets": [user1, user2],
        }
    except Exception as exc:
        record_dependency_unready("wallet-service")
        raise HTTPException(
            status_code=503,
            detail=degraded_response(
                "/api/admin/wallets",
                "wallet-service",
                str(exc),
            ),
        )