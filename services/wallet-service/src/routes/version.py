from fastapi import APIRouter
from src.config import BUILD_TIME, ENV, GIT_SHA, SERVICE_NAME, SERVICE_VERSION

router = APIRouter()


@router.get("/version")
def version():
    return {
        "service": SERVICE_NAME,
        "version": SERVICE_VERSION,
        "environment": ENV,
        "git_sha": GIT_SHA,
        "build_time": BUILD_TIME,
    }
