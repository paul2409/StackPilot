from fastapi import APIRouter, Query

from src.db import get_cursor

router = APIRouter()


@router.get("/history")
def history(username: str = Query(...)):
    with get_cursor() as cur:
        cur.execute(
            """
            SELECT id, username, type, amount, currency, description, created_at
            FROM transactions
            WHERE username = %s
            ORDER BY id DESC
            """,
            (username,),
        )
        rows = cur.fetchall()

    return {
        "username": username,
        "transactions": [
            {
                "id": row["id"],
                "type": row["type"],
                "amount": float(row["amount"]),
                "currency": row["currency"],
                "description": row["description"],
                "created_at": row["created_at"],
            }
            for row in rows
        ],
    }