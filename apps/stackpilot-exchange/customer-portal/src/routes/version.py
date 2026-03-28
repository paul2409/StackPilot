from fastapi import APIRouter
from src.config import SERVICE_NAME, SERVICE_VERSION, ENV

router = APIRouter()


@router.get("/version")
def version():
    return {
        "service": SERVICE_NAME,
        "version": SERVICE_VERSION,
        "environment": ENV,
    }