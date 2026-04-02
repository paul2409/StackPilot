from fastapi import FastAPI

from src.db import init_db
from src.observability import configure_metrics
from src.routes.auth import router as auth_router
from src.routes.me import router as me_router
from src.routes.users import router as users_router
from src.routes.health import router as health_router
from src.routes.version import router as version_router

app = FastAPI(title="Identity Service")
configure_metrics(app)


@app.on_event("startup")
def startup_event():
    init_db()


app.include_router(auth_router)
app.include_router(me_router)
app.include_router(users_router)
app.include_router(health_router)
app.include_router(version_router)


@app.get("/")
def root():
    return {"service": "identity-service", "status": "running"}
