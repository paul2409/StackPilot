from fastapi import APIRouter, HTTPException

from src.clients import system_client
from src.models.responses import degraded_response

router = APIRouter()


@router.get("/api/admin/system-summary")
def system_summary():
    try:
        data = system_client.status()
        return {
            "portal": "admin-portal",
            "status": "success",
            "system": data,
        }
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail=degraded_response(
                "/api/admin/system-summary",
                "system-service",
                str(exc),
            ),
        )