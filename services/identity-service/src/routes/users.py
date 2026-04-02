from fastapi import APIRouter

from src.db import get_cursor
from src.observability import record_lookup_request

router = APIRouter()


@router.get("/users")
def users():
    record_lookup_request("/users")
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