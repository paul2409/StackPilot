from fastapi import FastAPI

from src.db import init_db
from src.observability import configure_metrics
from src.routes.balances import router as balances_router
from src.routes.history import router as history_router
from src.routes.transfer import router as transfer_router
from src.routes.health import router as health_router
from src.routes.version import router as version_router

app = FastAPI(title="Wallet Service")
configure_metrics(app)


@app.on_event("startup")
def startup_event():
    init_db()


app.include_router(balances_router)
app.include_router(history_router)
app.include_router(transfer_router)
app.include_router(health_router)
app.include_router(version_router)


@app.get("/")
def root():
    return {"service": "wallet-service", "status": "running"}
