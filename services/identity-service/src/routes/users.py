from fastapi import APIRouter

from src.db import get_cursor

router = APIRouter()


@router.get("/users")
def users():
    with get_cursor() as cur:
        cur.execute(
            """
            SELECT username, full_name, role
            FROM users
            ORDER BY id
            """
        )
        rows = cur.fetchall()

    return {"users": rows}