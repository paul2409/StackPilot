import requests

from src.config import IDENTITY_SERVICE_URL, REQUEST_TIMEOUT


def get_health():
    response = requests.get(f"{IDENTITY_SERVICE_URL}/health", timeout=REQUEST_TIMEOUT)
    response.raise_for_status()
    return response.json()


def get_ready():
    response = requests.get(f"{IDENTITY_SERVICE_URL}/ready", timeout=REQUEST_TIMEOUT)
    response.raise_for_status()
    return response.json()


def get_version():
    response = requests.get(f"{IDENTITY_SERVICE_URL}/version", timeout=REQUEST_TIMEOUT)
    response.raise_for_status()
    return response.json()