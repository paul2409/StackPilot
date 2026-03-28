def portal_meta(service: str = "customer-portal"):
    return {"service": service}


def degraded_response(route: str, dependency: str, detail: str):
    return {
        "status": "degraded",
        "route": route,
        "dependency": dependency,
        "detail": detail,
    }