from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from src.clients import identity_client
from src.models.responses import degraded_response

router = APIRouter()


class LoginRequest(BaseModel):
    username: str
    password: str


@router.post("/api/auth/login")
def login(payload: LoginRequest):
    try:
        data = identity_client.login(payload.username, payload.password)
        return {"portal": "customer-portal", "status": "success", "auth": data}
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail=degraded_response("/api/auth/login", "identity-service", str(exc)),
        )


@router.get("/api/auth/me")
def me(token: str):
    try:
        data = identity_client.me(token)
        return {"portal": "customer-portal", "status": "success", "profile": data}
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail=degraded_response("/api/auth/me", "identity-service", str(exc)),
        )