from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from src.db import get_cursor
from src.observability import record_transfer_request

router = APIRouter()


class TransferRequest(BaseModel):
    username: str
    amount: float
    currency: str = "USD"
    description: str = "Transfer"


@router.post("/transfer")
def transfer(payload: TransferRequest):
    record_transfer_request()
    if payload.amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be positive")

    with get_cursor(commit=True) as cur:
        cur.execute(
            """
            SELECT amount
            FROM balances
            WHERE username = %s
            """,
            (payload.username,),
        )
        row = cur.fetchone()

        if not row:
            raise HTTPException(status_code=404, detail="Wallet not found")

        current_balance = float(row["amount"])
        if current_balance < payload.amount:
            raise HTTPException(status_code=400, detail="Insufficient balance")

        new_balance = current_balance - payload.amount

        cur.execute(
            """
            UPDATE balances
            SET amount = %s
            WHERE username = %s
            """,
            (new_balance, payload.username),
        )

        cur.execute(
            """
            INSERT INTO transactions (username, type, amount, currency, description)
            VALUES (%s, 'debit', %s, %s, %s)
            """,
            (payload.username, payload.amount, payload.currency, payload.description),
        )

    return {
        "status": "success",
        "username": payload.username,
        "new_balance": new_balance,
        "currency": payload.currency,
    }