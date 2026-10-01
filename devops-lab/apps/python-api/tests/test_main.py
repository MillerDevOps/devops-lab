from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_pagina_principal_es_html():
    r = client.get("/")
    assert r.status_code == 200
    assert "text/html" in r.headers["content-type"]
    assert "python-api" in r.text


def test_info_devuelve_datos_del_pod():
    r = client.get("/api/info")
    assert r.status_code == 200
    data = r.json()
    assert data["app"] == "python-api"
    assert "pod" in data and "version" in data


def test_saludo_usa_el_nombre():
    r = client.get("/api/saludo", params={"nombre": "Miller"})
    assert r.status_code == 200
    assert r.json()["mensaje"] == "Hola, Miller!"


def test_health():
    assert client.get("/health/live").status_code == 200
    assert client.get("/health/ready").status_code == 200


def test_metrics_expuestas():
    r = client.get("/metrics")
    assert r.status_code == 200
    assert "http_request" in r.text
