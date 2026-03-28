import requests
from src.config import SYSTEM_SERVICE_URL, REQUEST_TIMEOUT


def ready():
    response = requests.get(f"{SYSTEM_SERVICE_URL}/ready", timeout=REQUEST_TIMEOUT)
    response.raise_for_status()
    return response.json()


def status():
    response = requests.get(f"{SYSTEM_SERVICE_URL}/status", timeout=REQUEST_TIMEOUT)
    response.raise_for_status()
    return response.json()