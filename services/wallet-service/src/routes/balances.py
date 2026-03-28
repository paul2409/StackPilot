from fastapi import APIRouter, HTTPException, Query

from src.db import get_cursor

router = APIRouter()


@router.get("/balances")
def balances(username: str = Query(...)):
    with get_cursor() as cur:
        cur.execute(
            """
            SELECT username, currency, amount
            FROM balances
            WHERE username = %s
            """,
            (username,),
        )
        row = cur.fetchone()

    if not row:
        raise HTTPException(status_code=404, detail="Balance not found")

    return {
        "username": row["username"],
        "currency": row["currency"],
        "balance": float(row["amount"]),
    }