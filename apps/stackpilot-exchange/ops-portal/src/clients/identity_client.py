import requests

from src.config import IDENTITY_SERVICE_URL, REQUEST_TIMEOUT


def health():
    response = requests.get(f"{IDENTITY_SERVICE_URL}/health", timeout=REQUEST_TIMEOUT)
    response.raise_for_status()
    return response.json()


def ready():
    response = requests.get(f"{IDENTITY_SERVICE_URL}/ready", timeout=REQUEST_TIMEOUT)
    response.raise_for_status()
    return response.json()


def version():
    response = requests.get(f"{IDENTITY_SERVICE_URL}/version", timeout=REQUEST_TIMEOUT)
    response.raise_for_status()
    return response.json()