from fastapi import FastAPI

from src.routes.health import router as health_router
from src.routes.readiness import router as readiness_router
from src.routes.status import router as status_router
from src.routes.version import router as version_router
from src.observability import configure_metrics

app = FastAPI(title="System Service")
app.include_router(health_router)
app.include_router(readiness_router)
app.include_router(status_router)
app.include_router(version_router)

@app.get("/")
def root():
    return {
        "service": "system-service",
        "status": "running",
    }
