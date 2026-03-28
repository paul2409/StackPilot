from fastapi import APIRouter, HTTPException, Query

from src.db import get_cursor

router = APIRouter()


@router.get("/me")
def me(token: str = Query(...)):
    with get_cursor() as cur:
        cur.execute(
            """
            SELECT username, full_name, role, token
            FROM users
            WHERE token = %s
            """,
            (token,),
        )
        user = cur.fetchone()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return {
        "username": user["username"],
        "full_name": user["full_name"],
        "role": user["role"],
    }