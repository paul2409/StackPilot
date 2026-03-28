from fastapi import APIRouter, HTTPException

from src.clients import identity_client
from src.models.responses import degraded_response

router = APIRouter()


@router.get("/api/admin/users")
def users():
    try:
        # simple mock: reuse identity-service logic
        user = identity_client.me("token-customer1")
        return {
            "portal": "admin-portal",
            "users": [user],
        }
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail=degraded_response(
                "/api/admin/users",
                "identity-service",
                str(exc),
            ),
        )