from fastapi import FastAPI

from src.observability import configure_metrics
from src.routes.admin import router as admin_router
from src.routes.users import router as users_router
from src.routes.wallets import router as wallets_router
from src.routes.health import router as health_router
from src.routes.version import router as version_router

app = FastAPI(title="Admin Portal")
configure_metrics(app)

app.include_router(admin_router)
app.include_router(users_router)
app.include_router(wallets_router)
app.include_router(health_router)
app.include_router(version_router)


@app.get("/")
def root():
    return {"service": "admin-portal", "status": "running"}
