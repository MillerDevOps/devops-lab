import hashlib
import os
import socket
from datetime import datetime, timezone
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from prometheus_fastapi_instrumentator import Instrumentator

# La versión llega por variable de entorno (la pone el pipeline = hash del commit)
APP_VERSION = os.getenv("APP_VERSION", "dev")
# En Kubernetes, el hostname del contenedor es el nombre del pod
POD_NAME = socket.gethostname()
# Cada versión genera un color distinto: así se ve el cambio en cada despliegue
COLOR_HUE = int(hashlib.md5(APP_VERSION.encode()).hexdigest(), 16) % 360

PAGE = (Path(__file__).parent / "page.html").read_text(encoding="utf-8")

app = FastAPI(title="python-api", version=APP_VERSION)

# Expone /metrics en formato Prometheus (peticiones, latencia, códigos HTTP)
Instrumentator().instrument(app).expose(app, endpoint="/metrics", include_in_schema=False)


@app.get("/", response_class=HTMLResponse, include_in_schema=False)
def home():
    return PAGE.replace("__HUE__", str(COLOR_HUE))


@app.get("/api/info")
def info():
    return {
        "app": "python-api",
        "version": APP_VERSION,
        "pod": POD_NAME,
        "hue": COLOR_HUE,
        "hora": datetime.now(timezone.utc).strftime("%H:%M:%S UTC"),
        "lenguaje": "Python 3.12 + FastAPI",
    }


@app.get("/api/saludo")
def saludo(nombre: str = "mundo"):
    return {"mensaje": f"Hola, {nombre}!"}


# Endpoints para las probes de Kubernetes
@app.get("/health/live")
def live():
    return {"status": "UP"}


@app.get("/health/ready")
def ready():
    return {"status": "UP"}
