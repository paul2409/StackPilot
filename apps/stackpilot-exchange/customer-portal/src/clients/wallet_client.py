import requests
from src.config import WALLET_SERVICE_URL, REQUEST_TIMEOUT


def balances(username: str):
    response = requests.get(
        f"{WALLET_SERVICE_URL}/balances",
        params={"username": username},
        timeout=REQUEST_TIMEOUT,
    )
    response.raise_for_status()
    return response.json()


def history(username: str):
    response = requests.get(
        f"{WALLET_SERVICE_URL}/history",
        params={"username": username},
        timeout=REQUEST_TIMEOUT,
    )
    response.raise_for_status()
    return response.json()


def ready():
    response = requests.get(f"{WALLET_SERVICE_URL}/ready", timeout=REQUEST_TIMEOUT)
    response.raise_for_status()
    return response.json()