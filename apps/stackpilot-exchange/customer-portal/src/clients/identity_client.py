import requests
from src.config import IDENTITY_SERVICE_URL, REQUEST_TIMEOUT


def login(username: str, password: str):
    response = requests.post(
        f"{IDENTITY_SERVICE_URL}/login",
        json={"username": username, "password": password},
        timeout=REQUEST_TIMEOUT,
    )
    response.raise_for_status()
    return response.json()


def me(token: str):
    response = requests.get(
        f"{IDENTITY_SERVICE_URL}/me",
        params={"token": token},
        timeout=REQUEST_TIMEOUT,
    )
    response.raise_for_status()
    return response.json()


def ready():
    response = requests.get(f"{IDENTITY_SERVICE_URL}/ready", timeout=REQUEST_TIMEOUT)
    response.raise_for_status()
    return response.json()