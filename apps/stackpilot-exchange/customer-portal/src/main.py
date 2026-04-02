from fastapi import FastAPI

from src.routes.auth import router as auth_router
from src.routes.wallet import router as wallet_router
from src.routes.profile import router as profile_router
from src.routes.health import router as health_router
from src.routes.version import router as version_router
from src.observability import configure_metrics

app = FastAPI(title="Customer Portal")
app.include_router(auth_router)
app.include_router(wallet_router)
app.include_router(profile_router)
app.include_router(health_router)
app.include_router(version_router)

@app.get("/")
def root():
    return {"service": "customer-portal", "status": "running"}
