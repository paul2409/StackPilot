from fastapi import APIRouter, HTTPException
from src.clients import identity_client
from src.models.responses import degraded_response
from src.observability import record_auth_failure

router = APIRouter()


@router.get("/api/profile")
def profile(token: str):
    try:
        user = identity_client.me(token)
        return {
            "portal": "customer-portal",
            "status": "success",
            "profile": {
                "username": user["username"],
                "full_name": user["full_name"],
                "role": user["role"],
            },
        }
    except Exception as exc:
        record_auth_failure()
        raise HTTPException(
            status_code=503,
            detail=degraded_response("/api/profile", "identity-service", str(exc)),
        )