from fastapi import FastAPI

from src.routes.health import router as health_router
from src.routes.readiness import router as readiness_router
from src.routes.dependencies import router as dependencies_router
from src.routes.diagnostics import router as diagnostics_router
from src.routes.version import router as version_router
from src.observability import configure_metrics

app = FastAPI(title="Ops Portal")
app.include_router(health_router)
app.include_router(readiness_router)
app.include_router(dependencies_router)
app.include_router(diagnostics_router)
app.include_router(version_router)

@app.get("/")
def root():
    return {
        "service": "ops-portal",
        "status": "running",
    }
