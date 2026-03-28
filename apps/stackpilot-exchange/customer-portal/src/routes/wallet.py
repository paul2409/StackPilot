from fastapi import APIRouter, HTTPException
from src.clients import wallet_client
from src.models.responses import degraded_response

router = APIRouter()


@router.get("/api/wallet/balances")
def balances(username: str):
    try:
        data = wallet_client.balances(username)
        return {"portal": "customer-portal", "status": "success", "wallet": data}
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail=degraded_response("/api/wallet/balances", "wallet-service", str(exc)),
        )


@router.get("/api/wallet/history")
def history(username: str):
    try:
        data = wallet_client.history(username)
        return {"portal": "customer-portal", "status": "success", "history": data}
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail=degraded_response("/api/wallet/history", "wallet-service", str(exc)),
        )