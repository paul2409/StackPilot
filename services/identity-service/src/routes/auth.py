from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from src.db import get_cursor

router = APIRouter()


class LoginRequest(BaseModel):
    username: str
    password: str


@router.post("/login")
def login(payload: LoginRequest):
    # simple mock login, password not checked deeply for now
    with get_cursor() as cur:
        cur.execute(
            """
            SELECT username, full_name, role, token
            FROM users
            WHERE username = %s
            """,
            (payload.username,),
        )
        user = cur.fetchone()

    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    return {
        "access_token": user["token"],
        "token_type": "bearer",
        "user": {
            "username": user["username"],
            "full_name": user["full_name"],
            "role": user["role"],
        },
    }